import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_version_info.dart';
import '../services/update_service.dart';

/// Fetches the latest published version from the backend.
final latestVersionProvider = FutureProvider.autoDispose<AppVersionInfo>((ref) async {
  return UpdateService.instance.fetchLatestVersion();
});

/// Resolves to true once the installed version has been compared against
/// [latestVersionProvider] and found to be out of date.
final updateAvailableProvider = FutureProvider.autoDispose<bool>((ref) async {
  final latest = await ref.watch(latestVersionProvider.future);
  final current = await UpdateService.instance.currentVersion();
  return UpdateService.instance.isNewerVersion(current, latest.version);
});

enum UpdateDownloadStatus { idle, downloading, readyToInstall, error }

class UpdateDownloadState {
  const UpdateDownloadState({
    this.status = UpdateDownloadStatus.idle,
    this.progress = 0,
    this.filePath,
    this.errorMessage,
  });

  final UpdateDownloadStatus status;
  final double progress;
  final String? filePath;
  final String? errorMessage;

  UpdateDownloadState copyWith({
    UpdateDownloadStatus? status,
    double? progress,
    String? filePath,
    String? errorMessage,
  }) {
    return UpdateDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage,
    );
  }
}

/// Drives the APK download + install flow triggered from the update dialog.
class UpdateDownloadNotifier extends StateNotifier<UpdateDownloadState> {
  UpdateDownloadNotifier() : super(const UpdateDownloadState());

  CancelToken? _cancelToken;

  Future<void> downloadAndInstall(String apkUrl) async {
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = state.copyWith(status: UpdateDownloadStatus.downloading, progress: 0);
    try {
      final filePath = await UpdateService.instance.downloadApk(
        apkUrl,
        cancelToken: cancelToken,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
      state = state.copyWith(
        status: UpdateDownloadStatus.readyToInstall,
        filePath: filePath,
        progress: 1,
      );
      await UpdateService.instance.installApk(filePath);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        state = const UpdateDownloadState();
        return;
      }
      state = state.copyWith(
        status: UpdateDownloadStatus.error,
        errorMessage: e.toString(),
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateDownloadStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      _cancelToken = null;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }
}

final updateDownloadProvider =
    StateNotifierProvider.autoDispose<UpdateDownloadNotifier, UpdateDownloadState>(
  (ref) => UpdateDownloadNotifier(),
);

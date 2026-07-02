import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/app_version_info.dart';
import '../repositories/update_repository.dart';

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  final UpdateRepository _repository = UpdateRepository();

  Future<AppVersionInfo> fetchLatestVersion() => _repository.fetchLatestVersion();

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Returns true if [remoteVersion] is newer than [currentVersion].
  /// Compares dotted numeric segments (e.g. "1.2.10" > "1.2.9"), padding
  /// missing segments with 0 so "1.2" and "1.2.0" are treated as equal.
  bool isNewerVersion(String currentVersion, String remoteVersion) {
    final current = currentVersion.split('.').map(int.parse).toList();
    final remote = remoteVersion.split('.').map(int.parse).toList();
    final length = current.length > remote.length ? current.length : remote.length;

    for (var i = 0; i < length; i++) {
      final c = i < current.length ? current[i] : 0;
      final r = i < remote.length ? remote[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Downloads the APK at [apkUrl] to the app cache dir, reporting progress
  /// in [0, 1] via [onProgress], then returns the local file path.
  /// Pass [cancelToken] to allow the caller to cancel an in-flight download.
  Future<String> downloadApk(
    String apkUrl, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/app-release.apk';

    await Dio().download(
      apkUrl,
      filePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );

    return filePath;
  }

  /// Launches the Android package installer for the APK at [filePath].
  /// Requires the "Install unknown apps" permission for this app, which the
  /// user grants via the system settings screen if not already allowed.
  Future<void> installApk(String filePath) async {
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        await Permission.requestInstallPackages.request();
      }
    }
    await OpenFilex.open(filePath);
  }
}

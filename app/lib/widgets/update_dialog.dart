import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_version_info.dart';
import '../providers/update_provider.dart';

/// Shows the update dialog. When [versionInfo.forceUpdate] is true, the
/// dialog cannot be dismissed by back button, tap-outside, or close icon —
/// the user must download and install before continuing.
Future<void> showUpdateDialog(BuildContext context, AppVersionInfo versionInfo) {
  return showDialog(
    context: context,
    barrierDismissible: !versionInfo.forceUpdate,
    builder: (_) => UpdateDialog(versionInfo: versionInfo),
  );
}

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key, required this.versionInfo});

  final AppVersionInfo versionInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(updateDownloadProvider);
    final theme = Theme.of(context);
    final isDownloading = downloadState.status == UpdateDownloadStatus.downloading;
    final isReady = downloadState.status == UpdateDownloadStatus.readyToInstall;
    final hasError = downloadState.status == UpdateDownloadStatus.error;

    return PopScope(
      canPop: !versionInfo.forceUpdate,
      child: AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.system_update_rounded, color: theme.colorScheme.primary, size: 32),
        ),
        title: Text(
          versionInfo.forceUpdate ? 'Update Required' : 'Update Available',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${versionInfo.version} is available.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (versionInfo.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text("What's new", style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  versionInfo.releaseNotes,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            if (isDownloading) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: downloadState.progress,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(downloadState.progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (hasError) ...[
              const SizedBox(height: 12),
              Text(
                'Download failed. Please try again.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!versionInfo.forceUpdate && !isDownloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton.icon(
            onPressed: isDownloading
                ? null
                : () => ref
                    .read(updateDownloadProvider.notifier)
                    .downloadAndInstall(versionInfo.apkUrl),
            icon: isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(isReady ? Icons.install_mobile_rounded : Icons.download_rounded),
            label: Text(isDownloading ? 'Downloading…' : (isReady ? 'Install' : 'Update Now')),
          ),
        ],
      ),
    );
  }
}

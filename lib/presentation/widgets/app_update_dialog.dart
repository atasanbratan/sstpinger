import 'package:flutter/material.dart';

import '../../domain/entities/app_update_info.dart';
import '../theme/app_colors.dart';

/// A blocking "must update" dialog shown when the running version is below the
/// backend's `minVersion` (the lever for retiring builds on a dead deployment).
///
/// It is intentionally non-dismissible via barrier/back gestures: a tap on
/// "Download update" is the only way out. Kept dumb — the screen compares
/// versions and decides whether to show it; this widget only paints + routes
/// the download tap.
class AppUpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback onTapDownload;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onTapDownload,
  });

  /// The route the screen pushes; [barrierDismissible] is false and the PopScope
  /// blocks the system back gesture so only the download button dismisses it.
  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    required VoidCallback onTapDownload,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AppUpdateDialog(
          updateInfo: updateInfo,
          onTapDownload: onTapDownload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Update required'),
      content: Text(
        'This version of SSTP Shield is no longer supported. '
        'Please update to v${updateInfo.latestVersion} to continue.',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        FilledButton(
          onPressed: onTapDownload,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
          ),
          child: const Text('Download update'),
        ),
      ],
    );
  }
}

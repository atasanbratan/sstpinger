import 'package:flutter/material.dart';

import '../../domain/entities/app_update_info.dart';
import '../theme/app_colors.dart';

/// Dismissible advisory banner shown above the body when a newer build exists
/// but the running version is not below `minVersion`. Dismissing hides it for
/// the rest of the session (for the advertised `latestVersion`); the blocking
/// case is handled separately by [AppUpdateDialog] and cannot be dismissed.
///
/// Dumb widget: it only paints what it's given and routes taps to callbacks —
/// the screen owns the version comparison and event dispatch.
class AppUpdateBanner extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback onTapDownload;
  final VoidCallback onDismiss;

  const AppUpdateBanner({
    super.key,
    required this.updateInfo,
    required this.onTapDownload,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Dismissible(
        key: ValueKey(updateInfo.latestVersion),
        direction: DismissDirection.up,
        onDismissed: (_) => onDismiss(),
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 6, 18, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentBorderFaint),
          ),
          child: Row(
            children: [
              const Icon(Icons.system_update_outlined,
                  color: AppColors.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Update available: v${updateInfo.latestVersion}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ),
              GestureDetector(
                onTap: onTapDownload,
                child: Text(
                  'Get it',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

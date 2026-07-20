import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Modal bottom-sheet shown while the app downloads an APK update.
///
/// Dumb widget: the screen drives it by passing a [progressStream] (values
/// 0.0 → 1.0) and two callbacks. When [progressStream] emits 1.0 the sheet
/// switches from "Downloading…" to an "Install" button automatically.
///
/// Usage:
/// ```dart
/// await showModalBottomSheet(
///   context: context,
///   isDismissible: false,
///   builder: (_) => ApkDownloadSheet(
///     version: '2.4.0',
///     progressStream: controller.stream,
///     onInstall: _install,
///     onCancel: controller.cancel,
///   ),
/// );
/// ```
class ApkDownloadSheet extends StatefulWidget {
  final String version;
  final Stream<double> progressStream;
  final VoidCallback onInstall;
  final VoidCallback onCancel;

  const ApkDownloadSheet({
    super.key,
    required this.version,
    required this.progressStream,
    required this.onInstall,
    required this.onCancel,
  });

  @override
  State<ApkDownloadSheet> createState() => _ApkDownloadSheetState();
}

class _ApkDownloadSheetState extends State<ApkDownloadSheet> {
  double _progress = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    widget.progressStream.listen(
      (p) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          if (p >= 1.0) _done = true;
        });
      },
      onError: (_) {}, // errors are handled at the call site
      cancelOnError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle pill
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            _done ? 'Download complete' : 'Downloading update…',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v${widget.version}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 6,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation(
                _done ? AppColors.pingGood : AppColors.accent,
              ),
            ),
          ),
          if (!_done)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${(_progress * 100).round()} %',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textFaint),
                textAlign: TextAlign.end,
              ),
            ),
          const SizedBox(height: 24),

          // Action buttons
          if (_done)
            FilledButton.icon(
              onPressed: widget.onInstall,
              icon: const Icon(Icons.install_mobile_rounded),
              label: const Text('Install now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            )
          else
            OutlinedButton(
              onPressed: widget.onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel'),
            ),
        ],
      ),
    );
  }
}

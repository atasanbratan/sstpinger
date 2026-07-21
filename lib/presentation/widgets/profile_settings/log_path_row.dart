import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/logging/file_logger.dart';
import '../../theme/app_colors.dart';

/// Shows where the diagnostic log is written, with a copy button — the file
/// to send when a connection fails (a desktop GUI has no console to read).
class LogPathRow extends StatelessWidget {
  const LogPathRow({super.key});

  @override
  Widget build(BuildContext context) {
    final path = FileLogger.instance.path;
    if (path == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              size: 14, color: AppColors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Log: $path',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textFaint),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 14,
            tooltip: 'Copy log path',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log path copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

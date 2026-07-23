import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/logging/file_logger.dart';
import '../../theme/app_colors.dart';

/// Drill-down from Settings → Network → Diagnostic logs. Shows where the
/// diagnostic log is written — the file to send when a connection fails (a
/// desktop GUI has no console to read).
class DiagnosticLogsScreen extends StatelessWidget {
  const DiagnosticLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final path = FileLogger.instance.path;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Diagnostic Logs'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: path == null
            ? const Text(
                'No log file has been written yet.',
                style: TextStyle(color: AppColors.textMuted),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log file path',
                    style: TextStyle(fontSize: 11, color: AppColors.textFaint),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    path,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: path));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Log path copied')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy path'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accentBorder),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

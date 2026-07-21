import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// Max ping time and max simultaneous pings.
class PingSettingsCard extends StatelessWidget {
  final double timeoutSeconds;
  final ValueChanged<double> onTimeoutChanged;
  final int batchSize;
  final ValueChanged<int> onBatchSizeChanged;
  final VoidCallback onPersist;

  const PingSettingsCard({
    super.key,
    required this.timeoutSeconds,
    required this.onTimeoutChanged,
    required this.batchSize,
    required this.onBatchSizeChanged,
    required this.onPersist,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = timeoutSeconds.clamp(0.5, 5.0);
    final batch = batchSize.clamp(5, 300);

    return SettingsCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Max ping time',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                '${seconds.toStringAsFixed(1)}s',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: seconds.toDouble(),
            min: 0.5,
            max: 5.0,
            divisions: 9,
            activeColor: AppColors.accent,
            label: '${seconds.toStringAsFixed(1)}s',
            onChanged: onTimeoutChanged,
            onChangeEnd: (_) => onPersist(),
          ),
          const Divider(color: Colors.white10, height: 12),
          Row(
            children: [
              const Icon(Icons.bolt_outlined, color: AppColors.accentSecondary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Max simultaneous pings',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                '$batch',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentSecondary,
                ),
              ),
            ],
          ),
          Slider(
            value: batch.toDouble(),
            min: 5,
            max: 300,
            divisions: 59,
            activeColor: AppColors.accentSecondary,
            label: '$batch',
            onChanged: (v) => onBatchSizeChanged(v.round()),
            onChangeEnd: (_) => onPersist(),
          ),
        ],
      ),
    );
  }
}

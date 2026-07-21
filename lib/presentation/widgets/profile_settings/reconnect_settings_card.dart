import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// Retry count and retry interval for auto-reconnect.
class ReconnectSettingsCard extends StatelessWidget {
  final int retryCount;
  final ValueChanged<int> onRetryCountChanged;
  final int retryIntervalSeconds;
  final ValueChanged<int> onRetryIntervalChanged;
  final VoidCallback onPersist;

  const ReconnectSettingsCard({
    super.key,
    required this.retryCount,
    required this.onRetryCountChanged,
    required this.retryIntervalSeconds,
    required this.onRetryIntervalChanged,
    required this.onPersist,
  });

  @override
  Widget build(BuildContext context) {
    final count = retryCount.clamp(0, 10);
    final interval = retryIntervalSeconds.clamp(1, 60);

    return SettingsCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.refresh_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Retry count',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                count == 0 ? 'Off' : '$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: count.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: AppColors.accent,
            label: count == 0 ? 'Off' : '$count',
            onChanged: (v) => onRetryCountChanged(v.round()),
            onChangeEnd: (_) => onPersist(),
          ),
          const Divider(color: Colors.white10, height: 12),
          Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Retry interval',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                '${interval}s',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentSecondary,
                ),
              ),
            ],
          ),
          Slider(
            value: interval.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            activeColor: AppColors.accentSecondary,
            label: '${interval}s',
            onChanged: (v) => onRetryIntervalChanged(v.round()),
            onChangeEnd: (_) => onPersist(),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// How many servers each fetch pulls from the backend (50–5000). More servers
/// means a fuller list but a heavier fetch.
class FetchCountCard extends StatelessWidget {
  final int count;
  final ValueChanged<int> onChanged;
  final VoidCallback onPersist;

  const FetchCountCard({
    super.key,
    required this.count,
    required this.onChanged,
    required this.onPersist,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = count.clamp(50, 5000);

    return SettingsCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.dns_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Servers per fetch',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                '$clamped',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: clamped.toDouble(),
            min: 50,
            max: 5000,
            divisions: 99, // steps of 50
            activeColor: AppColors.accent,
            label: '$clamped',
            onChanged: (v) => onChanged(v.round()),
            onChangeEnd: (_) => onPersist(),
          ),
        ],
      ),
    );
  }
}

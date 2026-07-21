import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// SoftEther transport: which mode to try first (NAT-T disabled = direct TCP)
/// and how long to wait before falling back to the other. VPN Gate relays are
/// split on which one works, so the app always tries both — this just tunes
/// the order and patience.
class SoftEtherNatTCard extends StatelessWidget {
  final bool disableNatT;
  final ValueChanged<bool> onDisableNatTChanged;
  final int retryWaitSeconds;
  final ValueChanged<int> onRetryWaitChanged;
  final VoidCallback onPersist;

  const SoftEtherNatTCard({
    super.key,
    required this.disableNatT,
    required this.onDisableNatTChanged,
    required this.retryWaitSeconds,
    required this.onRetryWaitChanged,
    required this.onPersist,
  });

  @override
  Widget build(BuildContext context) {
    final wait = retryWaitSeconds.clamp(5, 60);

    return SettingsCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lan_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Disable NAT-T (direct TCP first)',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              Switch(
                value: disableNatT,
                activeThumbColor: AppColors.accent,
                onChanged: (val) {
                  onDisableNatTChanged(val);
                  onPersist();
                },
              ),
            ],
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
                  'Wait before trying the other',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                '${wait}s',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentSecondary,
                ),
              ),
            ],
          ),
          Slider(
            value: wait.toDouble(),
            min: 5,
            max: 60,
            divisions: 55,
            activeColor: AppColors.accentSecondary,
            label: '${wait}s',
            onChanged: (v) => onRetryWaitChanged(v.round()),
            onChangeEnd: (_) => onPersist(),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../domain/entities/ping_mode.dart';
import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// Reachability check mode. Fast = a TCP connect (open port). Accurate = a TLS
/// handshake through the uTLS relay, so the latency reflects what SSTP actually
/// needs — a server whose TLS is blocked reads as unreachable, not falsely fast.
class PingModeCard extends StatelessWidget {
  final PingMode mode;
  final ValueChanged<PingMode> onChanged;

  const PingModeCard({super.key, required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reachability check',
              style: TextStyle(fontSize: 13, color: Colors.white)),
          const SizedBox(height: 3),
          const Text(
            'Accurate does a real TLS handshake (via the relay) — slower, but a '
            'server it marks reachable can actually connect.',
            style: TextStyle(fontSize: 10.5, color: AppColors.textFaint),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _PingModePill(
                label: 'Fast',
                sub: 'TCP connect',
                icon: Icons.bolt_rounded,
                active: mode == PingMode.tcp,
                onTap: () => onChanged(PingMode.tcp),
              ),
              const SizedBox(width: 10),
              _PingModePill(
                label: 'Accurate',
                sub: 'TLS handshake',
                icon: Icons.verified_user_rounded,
                active: mode == PingMode.tls,
                onTap: () => onChanged(PingMode.tls),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PingModePill extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _PingModePill({
    required this.label,
    required this.sub,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: active ? AppColors.accent : AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppColors.accent : AppColors.divider,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 18,
                    color: active ? AppColors.surfaceDeep : AppColors.textMuted),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.surfaceDeep : AppColors.textMuted,
                    )),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          active ? AppColors.surfaceDeep : AppColors.textFaint,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

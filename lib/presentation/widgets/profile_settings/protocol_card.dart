import 'package:flutter/material.dart';

import '../../../domain/entities/tunnel_protocol.dart';
import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// Protocol selector: SSTP is active; SoftEther is shown disabled with a
/// "SOON" badge (a placeholder until the protocol is implemented).
class ProtocolCard extends StatelessWidget {
  final TunnelProtocol selected;
  final ValueChanged<TunnelProtocol> onChanged;

  const ProtocolCard({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(child: _ProtocolChip(
            protocol: TunnelProtocol.sstp,
            selected: selected == TunnelProtocol.sstp,
            onChanged: onChanged,
          )),
          const SizedBox(width: 10),
          Expanded(child: _ProtocolChip(
            protocol: TunnelProtocol.softEther,
            selected: selected == TunnelProtocol.softEther,
            onChanged: onChanged,
          )),
        ],
      ),
    );
  }
}

class _ProtocolChip extends StatelessWidget {
  final TunnelProtocol protocol;
  final bool selected;
  final ValueChanged<TunnelProtocol> onChanged;

  const _ProtocolChip({
    required this.protocol,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = protocol.available;

    final chip = Material(
      color: selected ? AppColors.accent : AppColors.inputBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled && !selected ? () => onChanged(protocol) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.shield_outlined,
                size: 16,
                color: selected ? AppColors.surfaceDeep : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  protocol.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.surfaceDeep
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (!enabled) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDeep,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SOON',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return enabled ? chip : Opacity(opacity: 0.55, child: chip);
  }
}

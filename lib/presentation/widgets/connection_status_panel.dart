import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/tunnel_status.dart';
import '../theme/app_colors.dart';

class ConnectionStatusPanel extends StatelessWidget {
  final TunnelStatus status;
  final Duration duration;
  final VoidCallback onToggle;

  const ConnectionStatusPanel({
    super.key,
    required this.status,
    required this.duration,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isConnected = status == TunnelStatus.connected;
    final bool isConnecting = status == TunnelStatus.connecting;

    Color statusColor = AppColors.disconnected;
    String statusText = 'DISCONNECTED';

    if (isConnected) {
      statusColor = AppColors.connected;
      statusText = 'CONNECTED';
    } else if (isConnecting) {
      statusColor = AppColors.connecting;
      statusText = 'CONNECTING...';
    }

    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.06),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
              ),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.15),
                      blurRadius: isConnecting ? 25 : 15,
                      spreadRadius: isConnecting ? 5 : 2,
                    ),
                  ],
                ),
              ),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.statusButtonCore,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.8),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 48,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isConnected ? Formatters.duration(duration) : '00:00:00',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

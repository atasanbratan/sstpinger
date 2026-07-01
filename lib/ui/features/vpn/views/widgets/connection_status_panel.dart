import 'package:flutter/material.dart';

import '../../view_models/vpn_view_model.dart';

class ConnectionStatusPanel extends StatelessWidget {
  final VpnViewModel viewModel;
  final VoidCallback onToggle;
  final String Function(Duration) formatDuration;

  const ConnectionStatusPanel({
    super.key,
    required this.viewModel,
    required this.onToggle,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final bool isConnected =
        viewModel.connectionStatus == SSTPConnectionStatusKeys.CONNECTED;
    final bool isConnecting =
        viewModel.connectionStatus == SSTPConnectionStatusKeys.CONNECTING;

    Color statusColor = Colors.grey;
    String statusText = 'DISCONNECTED';

    if (isConnected) {
      statusColor = const Color(0xFF10B981);
      statusText = 'CONNECTED';
    } else if (isConnecting) {
      statusColor = const Color(0xFFF59E0B);
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
                  color: const Color(0xFF1F293D),
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
          isConnected ? formatDuration(viewModel.duration) : '00:00:00',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

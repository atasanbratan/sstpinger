import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/tunnel_status.dart';
import '../bloc/connection/connection_bloc.dart';
import '../theme/app_colors.dart';

/// The hero connect control: a large circular power button with concentric
/// rings, carrying the status label and the session timer *inside* the ring.
///
/// All inner metrics scale off [size] (the outer halo's diameter), keeping the
/// original proportions at any size.
class PowerButton extends StatelessWidget {
  /// The reference design was tuned at a 220px outer halo — every inner ring,
  /// icon and font size below is expressed relative to it.
  static const double _referenceSize = 220;

  final TunnelStatus status;
  final VoidCallback onToggle;
  final double size;

  const PowerButton({
    super.key,
    required this.status,
    required this.onToggle,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = status == TunnelStatus.connected;
    final isConnecting = status == TunnelStatus.connecting;
    final scale = size / _referenceSize;

    final (Color color, String label) = switch (status) {
      TunnelStatus.connected => (AppColors.connected, 'CONNECTED'),
      TunnelStatus.connecting => (AppColors.connecting, 'CONNECTING'),
      TunnelStatus.disconnecting => (AppColors.connecting, 'DISCONNECTING'),
      TunnelStatus.disconnected => (AppColors.disconnected, 'DISCONNECTED'),
    };

    return Semantics(
      button: true,
      label: isConnected ? 'Disconnect' : 'Connect',
      child: GestureDetector(
        onTap: onToggle,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outermost halo.
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.04),
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              // Glow ring — swells while connecting.
              Container(
                width: 186 * scale,
                height: 186 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.06),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: isConnected ? 0.28 : 0.15),
                      blurRadius: (isConnecting ? 30 : 20) * scale,
                      spreadRadius: (isConnecting ? 6 : 2) * scale,
                    ),
                  ],
                ),
              ),
              // Core, holding the icon + status + timer.
              Container(
                width: 156 * scale,
                height: 156 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.statusButtonCore,
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.power_settings_new_rounded,
                      size: 40 * scale,
                      color: color,
                    ),
                    SizedBox(height: 10 * scale),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        fontSize: 11 * scale,
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    BlocBuilder<ConnectionBloc, VpnConnectionState>(
                      buildWhen: (previous, current) =>
                          previous.duration != current.duration ||
                          previous.isConnected != current.isConnected,
                      builder: (context, conn) => Text(
                        conn.isConnected
                            ? Formatters.duration(conn.duration)
                            : '00:00:00',
                        style: TextStyle(
                          fontSize: 15 * scale,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

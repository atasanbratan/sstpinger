import 'package:flutter/material.dart';

import '../../core/utils/country_flag.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/tunnel_traffic.dart';
import '../../domain/entities/vpn_server.dart';
import '../theme/app_colors.dart';
import 'speed_indicator.dart';

/// The node the app will connect to (or is connected to), shown centred beneath
/// the power button: flag, name, endpoint, and — while connected — throughput.
class ConnectionControlCard extends StatelessWidget {
  final bool isConnected;
  final VpnServer? server;
  final bool useCustomConfig;
  final String customHost;
  final String customPort;
  final TunnelTraffic? traffic;

  const ConnectionControlCard({
    super.key,
    required this.isConnected,
    required this.server,
    required this.useCustomConfig,
    required this.customHost,
    required this.customPort,
    required this.traffic,
  });

  @override
  Widget build(BuildContext context) {
    final custom = useCustomConfig;

    final String name = custom
        ? 'Custom node'
        : (server?.country.toUpperCase() ?? 'NO NODE SELECTED');
    final String subtitle = custom
        ? '$customHost:$customPort'
        : (server?.hostname ?? 'Pick one from the list below');

    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceDeep,
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            custom
                ? '🔧'
                : (server != null ? countryFlagEmoji(server!.countryShort) : '🌐'),
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
        ),
        if (isConnected) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  SpeedIndicator(
                    label: 'DOWNLOAD',
                    speed: Formatters.speed(traffic?.downloadTraffic ?? 0),
                    total: Formatters.bytes(traffic?.totalDownloadTraffic ?? 0),
                    icon: Icons.arrow_downward_rounded,
                    color: AppColors.accent,
                  ),
                  Container(height: 36, width: 1, color: AppColors.divider),
                  SpeedIndicator(
                    label: 'UPLOAD',
                    speed: Formatters.speed(traffic?.uploadTraffic ?? 0),
                    total: Formatters.bytes(traffic?.totalUploadTraffic ?? 0),
                    icon: Icons.arrow_upward_rounded,
                    color: AppColors.accentSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

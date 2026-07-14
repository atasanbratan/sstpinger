import 'package:flutter/material.dart';

import '../../../../../core/utils/country_flag.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../core/app_colors.dart';
import '../../view_models/vpn_view_model.dart';
import 'speed_indicator.dart';

class ConnectionControlCard extends StatelessWidget {
  final VpnViewModel viewModel;

  const ConnectionControlCard({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final bool isConnected =
        viewModel.connectionStatus == SSTPConnectionStatusKeys.connected;

    final server = viewModel.selectedServer;
    final custom = viewModel.useCustomConfig;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surface,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDeep,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    custom
                        ? '🔧'
                        : (server != null
                              ? countryFlagEmoji(server.countryShort)
                              : '🌐'),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        custom
                            ? 'Custom Node Configuration'
                            : (server != null
                                  ? server.country.toUpperCase()
                                  : 'No Node Selected'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        custom
                            ? '${viewModel.customHostController.text}:${viewModel.customPortController.text}'
                            : (server != null
                                  ? server.hostname
                                  : 'Select from server list below'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (custom ? AppColors.connecting : AppColors.accent)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    custom ? 'CUSTOM' : 'API NODES',
                    style: TextStyle(
                      fontSize: 9,
                      color: custom
                          ? AppColors.connecting
                          : AppColors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (isConnected) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(color: AppColors.divider),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  SpeedIndicator(
                    label: 'DOWNLOAD SPEED',
                    speed: Formatters.speed(
                      viewModel.traffic?.downloadTraffic ?? 0,
                    ),
                    total: Formatters.bytes(
                      viewModel.traffic?.totalDownloadTraffic ?? 0,
                    ),
                    icon: Icons.arrow_downward_rounded,
                    color: AppColors.accent,
                  ),
                  Container(height: 40, width: 1, color: AppColors.divider),
                  SpeedIndicator(
                    label: 'UPLOAD SPEED',
                    speed: Formatters.speed(
                      viewModel.traffic?.uploadTraffic ?? 0,
                    ),
                    total: Formatters.bytes(
                      viewModel.traffic?.totalUploadTraffic ?? 0,
                    ),
                    icon: Icons.arrow_upward_rounded,
                    color: AppColors.accentSecondary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

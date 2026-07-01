import 'dart:math';
import 'package:flutter/material.dart';

import '../../view_models/vpn_view_model.dart';

class ConnectionControlCard extends StatelessWidget {
  final VpnViewModel viewModel;
  final String Function(String) getFlagEmoji;
  final Widget Function({
    required String label,
    required String speed,
    required String total,
    required IconData icon,
    required Color color,
  })
  buildSpeedIndicator;

  const ConnectionControlCard({
    super.key,
    required this.viewModel,
    required this.getFlagEmoji,
    required this.buildSpeedIndicator,
  });

  @override
  Widget build(BuildContext context) {
    final bool isConnected =
        viewModel.connectionStatus == SSTPConnectionStatusKeys.CONNECTED;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF151D30),
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
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    viewModel.useCustomConfig
                        ? '🔧'
                        : (viewModel.selectedServer != null
                              ? getFlagEmoji(
                                  viewModel.selectedServer!.countryShort,
                                )
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
                        viewModel.useCustomConfig
                            ? 'Custom Node Configuration'
                            : (viewModel.selectedServer != null
                                  ? viewModel.selectedServer!.country
                                        .toUpperCase()
                                  : 'No Node Selected'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        viewModel.useCustomConfig
                            ? '${viewModel.customHostController.text}:${viewModel.customPortController.text}'
                            : (viewModel.selectedServer != null
                                  ? viewModel.selectedServer!.hostname
                                  : 'Select from server list below'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
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
                    color: viewModel.useCustomConfig
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    viewModel.useCustomConfig ? 'CUSTOM' : 'API NODES',
                    style: TextStyle(
                      fontSize: 9,
                      color: viewModel.useCustomConfig
                          ? Colors.orangeAccent
                          : const Color(0xFF00D2FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (isConnected) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(color: Colors.white10),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  buildSpeedIndicator(
                    label: 'DOWNLOAD SPEED',
                    speed: viewModel.traffic != null
                        ? _formatSpeed(viewModel.traffic!.downloadTraffic ?? 0)
                        : '0.0 KB/s',
                    total: viewModel.traffic != null
                        ? _formatTraffic(
                            viewModel.traffic!.totalDownloadTraffic ?? 0,
                          )
                        : '0.0 MB',
                    icon: Icons.arrow_downward_rounded,
                    color: const Color(0xFF00D2FF),
                  ),
                  Container(height: 40, width: 1, color: Colors.white10),
                  buildSpeedIndicator(
                    label: 'UPLOAD SPEED',
                    speed: viewModel.traffic != null
                        ? _formatSpeed(viewModel.traffic!.uploadTraffic ?? 0)
                        : '0.0 KB/s',
                    total: viewModel.traffic != null
                        ? _formatTraffic(
                            viewModel.traffic!.totalUploadTraffic ?? 0,
                          )
                        : '0.0 MB',
                    icon: Icons.arrow_upward_rounded,
                    color: const Color(0xFF9D4EDD),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var i = (log(bytesPerSecond) / log(1024)).floor();
    i = i.clamp(0, suffixes.length - 1);
    return '${(bytesPerSecond / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatTraffic(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    i = i.clamp(0, suffixes.length - 1);
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}

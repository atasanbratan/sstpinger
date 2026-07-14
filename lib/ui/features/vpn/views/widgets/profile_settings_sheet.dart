import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/app_colors.dart';
import '../../view_models/vpn_view_model.dart';

class ProfileSettingsSheet extends StatelessWidget {
  final VpnViewModel viewModel;
  final VoidCallback onEditUsername;
  final VoidCallback onRenew;
  final String renewLabel;
  final ValueChanged<bool> onUseCustomConfigChanged;

  const ProfileSettingsSheet({
    super.key,
    required this.viewModel,
    required this.onEditUsername,
    required this.onRenew,
    this.renewLabel = 'RENEW ACTIVATION CODE',
    required this.onUseCustomConfigChanged,
  });

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final local = date.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${_months[local.month - 1]} ${local.day}, ${local.year}  $h:$m';
  }

  Widget _buildSubscriptionCard() {
    final expireTime = viewModel.expireTime;
    final lastFetch = viewModel.lastFetchTime;
    final bool expired = viewModel.isSubscriptionExpired;

    final Color expiryColor = expired
        ? AppColors.error
        : AppColors.accent;

    return Card(
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  expired
                      ? Icons.error_outline
                      : Icons.workspace_premium_outlined,
                  color: expiryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expired ? 'Expired on' : 'Expires on',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                      Text(
                        _formatDate(expireTime),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: expiryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              children: [
                const Icon(Icons.update, color: Colors.white54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Server list last updated',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                      Text(
                        _formatDate(lastFetch),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPingSettingsCard(StateSetter setModalState) {
    final seconds = viewModel.pingTimeoutSeconds.clamp(0.5, 5.0);
    final batch = viewModel.pingBatchSize.clamp(5, 100);

    return Card(
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Max ping time',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
                Text(
                  '${seconds.toStringAsFixed(1)}s',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            Slider(
              value: seconds.toDouble(),
              min: 0.5,
              max: 5.0,
              divisions: 9,
              activeColor: AppColors.accent,
              label: '${seconds.toStringAsFixed(1)}s',
              onChanged: (v) {
                setModalState(() => viewModel.setPingTimeoutSeconds(v));
              },
              onChangeEnd: (_) => viewModel.persistPingSettings(),
            ),
            const Divider(color: Colors.white10, height: 12),
            Row(
              children: [
                const Icon(Icons.bolt_outlined, color: AppColors.accentSecondary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Max simultaneous pings',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
                Text(
                  '$batch',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentSecondary,
                  ),
                ),
              ],
            ),
            Slider(
              value: batch.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              activeColor: AppColors.accentSecondary,
              label: '$batch',
              onChanged: (v) {
                setModalState(() => viewModel.setPingBatchSize(v.round()));
              },
              onChangeEnd: (_) => viewModel.persistPingSettings(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'SETTINGS & PROFILE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'USER PROFILE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: AppColors.surfaceRaised,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Username',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  Text(
                                    viewModel.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: onEditUsername,
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 24),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_android,
                              color: AppColors.accentSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Device Advertising ID',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  Text(
                                    viewModel.deviceId,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: viewModel.deviceId),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Device ID copied to clipboard',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'SUBSCRIPTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSubscriptionCard(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onRenew,
                    icon: const Icon(Icons.autorenew, size: 18),
                    label: Text(renewLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accentBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'PING SETTINGS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPingSettingsCard(setModalState),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'USE CUSTOM NODE SETTINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                      ),
                    ),
                    Switch(
                      value: viewModel.useCustomConfig,
                      activeThumbColor: AppColors.accent,
                      onChanged: (val) {
                        setModalState(() {
                          onUseCustomConfigChanged(val);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (viewModel.useCustomConfig) ...[
                  TextField(
                    controller: viewModel.customHostController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Host IP / Hostname',
                      labelStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: viewModel.customPortController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            labelStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: viewModel.customUsernameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'VPN User',
                            labelStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.accent),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: viewModel.customPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'VPN Password',
                      labelStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }
}

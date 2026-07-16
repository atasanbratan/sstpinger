import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/tunnel_protocol.dart';
import '../bloc/vpn/vpn_bloc.dart';
import '../theme/app_colors.dart';

class ProfileSettingsSheet extends StatelessWidget {
  final VoidCallback onEditUsername;
  final VoidCallback onRenew;

  /// Renew by loading the activation-code file (the admin console's Download).
  /// Null hides the option (e.g. the foreign variant, which renews via payment).
  final VoidCallback? onRenewFromFile;
  final String renewLabel;
  final TextEditingController customHostController;
  final TextEditingController customPortController;
  final TextEditingController customUsernameController;
  final TextEditingController customPasswordController;

  const ProfileSettingsSheet({
    super.key,
    required this.onEditUsername,
    required this.onRenew,
    this.onRenewFromFile,
    this.renewLabel = 'RENEW ACTIVATION CODE',
    required this.customHostController,
    required this.customPortController,
    required this.customUsernameController,
    required this.customPasswordController,
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

  Widget _buildSubscriptionCard(VpnState vpn) {
    final bool expired = vpn.isSubscriptionExpired;
    final Color expiryColor = expired ? AppColors.error : AppColors.accent;

    return Card(
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                        style: const TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                      Text(
                        _formatDate(vpn.expireTime),
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
                        style: TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                      Text(
                        _formatDate(vpn.lastFetchTime),
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
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

  /// Protocol selector: SSTP is active; SoftEther is shown disabled with a
  /// "SOON" badge (a placeholder until the protocol is implemented).
  Widget _buildProtocolCard(BuildContext context, VpnState vpn) {
    final bloc = context.read<VpnBloc>();
    return Card(
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: _protocolChip(bloc, vpn, TunnelProtocol.sstp)),
            const SizedBox(width: 10),
            Expanded(child: _protocolChip(bloc, vpn, TunnelProtocol.softEther)),
          ],
        ),
      ),
    );
  }

  Widget _protocolChip(VpnBloc bloc, VpnState vpn, TunnelProtocol protocol) {
    final selected = vpn.protocol == protocol;
    final enabled = protocol.available;

    final chip = Material(
      color: selected ? AppColors.accent : AppColors.inputBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled && !selected
            ? () => bloc.add(ProtocolChanged(protocol))
            : null,
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

  Widget _buildPingSettingsCard(BuildContext context, VpnState vpn) {
    final seconds = vpn.pingTimeoutSeconds.clamp(0.5, 5.0);
    final batch = vpn.pingBatchSize.clamp(5, 100);
    final bloc = context.read<VpnBloc>();

    return Card(
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              onChanged: (v) => bloc.add(PingTimeoutChanged(v)),
              onChangeEnd: (_) => bloc.add(const PingSettingsPersistRequested()),
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
              onChanged: (v) => bloc.add(PingBatchSizeChanged(v.round())),
              onChangeEnd: (_) => bloc.add(const PingSettingsPersistRequested()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReconnectSettingsCard(BuildContext context, VpnState vpn) {
    final count = vpn.reconnectRetryCount.clamp(0, 10);
    final interval = vpn.reconnectRetryIntervalSeconds.clamp(1, 60);
    final bloc = context.read<VpnBloc>();

    return Card(
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.refresh_rounded, color: AppColors.accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Retry count',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
                Text(
                  count == 0 ? 'Off' : '$count',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            Slider(
              value: count.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              activeColor: AppColors.accent,
              label: count == 0 ? 'Off' : '$count',
              onChanged: (v) => bloc.add(ReconnectRetryCountChanged(v.round())),
              onChangeEnd: (_) =>
                  bloc.add(const ReconnectSettingsPersistRequested()),
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
                    'Retry interval',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
                Text(
                  '${interval}s',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentSecondary,
                  ),
                ),
              ],
            ),
            Slider(
              value: interval.toDouble(),
              min: 1,
              max: 60,
              divisions: 59,
              activeColor: AppColors.accentSecondary,
              label: '${interval}s',
              onChanged: (v) =>
                  bloc.add(ReconnectRetryIntervalChanged(v.round())),
              onChangeEnd: (_) =>
                  bloc.add(const ReconnectSettingsPersistRequested()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, vpn) {
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
                      borderRadius: BorderRadius.circular(14),
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
                    borderRadius: BorderRadius.circular(14),
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
                                    vpn.username,
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
                                    vpn.deviceId,
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
                                  ClipboardData(text: vpn.deviceId),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Device ID copied to clipboard'),
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
                _buildSubscriptionCard(vpn),
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (onRenewFromFile != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onRenewFromFile,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('RENEW FROM FILE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accentBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'PROTOCOL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                _buildProtocolCard(context, vpn),
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
                _buildPingSettingsCard(context, vpn),
                const SizedBox(height: 20),
                const Text(
                  'RECONNECTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 8),
                _buildReconnectSettingsCard(context, vpn),
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
                      value: vpn.useCustomConfig,
                      activeThumbColor: AppColors.accent,
                      onChanged: (val) => context.read<VpnBloc>().add(
                        UseCustomConfigChanged(val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (vpn.useCustomConfig) ...[
                  TextField(
                    controller: customHostController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Host IP / Hostname',
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
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
                          controller: customPortController,
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
                          controller: customUsernameController,
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
                    controller: customPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'VPN Password',
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
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

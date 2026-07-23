import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/lan_ip.dart';
import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// Lets other LAN devices route through this device's active VPN tunnel via a
/// local SOCKS5 proxy. The port change only takes effect on the next connect
/// (the listener only starts once the tunnel is up).
///
/// Wired up on desktop (Linux/Windows) and Android — see
/// [Socks5ProxyDataSource] and `ConnectionBloc`'s proxy-sharing hook. Shown on
/// every platform anyway (best-effort placeholder on iOS, where there's no
/// implementation) so the setting is saved and ready once support lands
/// there; [_unsupported] surfaces that gap instead of silently doing nothing.
class ProxySharingCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final int port;
  final ValueChanged<int> onPortChanged;
  final VoidCallback onPersist;

  const ProxySharingCard({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.port,
    required this.onPortChanged,
    required this.onPersist,
  });

  bool get _unsupported =>
      !Platform.isLinux && !Platform.isWindows && !Platform.isAndroid;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.share_rounded, color: AppColors.accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Share via proxy (SOCKS5)',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: AppColors.accent,
                onChanged: (val) {
                  onEnabledChanged(val);
                  onPersist();
                },
              ),
            ],
          ),
          if (enabled) ...[
            const Divider(color: Colors.white10, height: 12),
            Row(
              children: [
                const Icon(
                  Icons.numbers_rounded,
                  color: AppColors.accentSecondary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Port',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
                Text(
                  '$port',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentSecondary,
                  ),
                ),
              ],
            ),
            Slider(
              value: port.toDouble(),
              min: 1024,
              max: 65535,
              activeColor: AppColors.accentSecondary,
              label: '$port',
              onChanged: (v) => onPortChanged(v.round()),
              onChangeEnd: (_) => onPersist(),
            ),
            const SizedBox(height: 4),
            if (_unsupported)
              const Text(
                'Not yet functional on this device — the setting is saved '
                'for when support lands here. Works today on Linux, '
                'Windows, and Android.',
                style: TextStyle(fontSize: 11, color: AppColors.connecting),
              )
            else
              FutureBuilder<String?>(
                future: currentLanIp(),
                builder: (context, snapshot) {
                  final ip = snapshot.data;
                  final text = ip == null
                      ? 'Connect once the VPN is on — point other devices\' '
                            'SOCKS5 client at this machine\'s LAN IP, port $port.'
                      : 'Point other devices\' SOCKS5 client at $ip:$port '
                            'once the VPN is on.';
                  return Text(
                    text,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textFaint,
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

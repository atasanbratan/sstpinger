import 'package:flutter/material.dart';

import '../../bloc/vpn/vpn_bloc.dart';
import '../../theme/app_colors.dart';

/// Right-aligned count: "N available", plus a green "· M reachable" clause once
/// servers have been pinged. Shows ping progress while a ping is running.
class ServerCountLabel extends StatelessWidget {
  final VpnState vpn;

  const ServerCountLabel(this.vpn, {super.key});

  @override
  Widget build(BuildContext context) {
    if (vpn.isPinging) {
      return Text(
        'Pinging ${vpn.pingProgress}/${vpn.pingTotal} · ${vpn.pingPercent}%',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
        ),
      );
    }

    final servers = vpn.filteredServers;
    final reachable = servers.where((s) => s.ping != null).length;
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
        children: [
          TextSpan(text: '${servers.length} available'),
          if (reachable > 0)
            TextSpan(
              text: ' · $reachable reachable',
              style: const TextStyle(
                color: AppColors.pingGood,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

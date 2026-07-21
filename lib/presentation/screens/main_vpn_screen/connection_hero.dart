import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/connection/connection_bloc.dart';
import '../../bloc/vpn/vpn_bloc.dart';
import '../../widgets/power_button.dart';

/// The power button and the node it will use.
class ConnectionHero extends StatelessWidget {
  final VpnState vpn;
  final void Function(VpnState vpn, bool isActive) onToggle;

  const ConnectionHero({super.key, required this.vpn, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionBloc, VpnConnectionState>(
      builder: (context, conn) => Column(
        children: [
          PowerButton(
            status: conn.status,
            onToggle: () => onToggle(vpn, conn.isConnected),
          ),
        ],
      ),
    );
  }
}

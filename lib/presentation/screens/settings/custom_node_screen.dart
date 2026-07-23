import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/vpn/vpn_bloc.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_settings/custom_node_settings.dart';

/// Drill-down from Settings → Network → Custom node. The controllers are
/// owned by `_MainVpnScreenState` and threaded through unchanged — this
/// screen doesn't create or dispose them.
class CustomNodeScreen extends StatelessWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  const CustomNodeScreen({
    super.key,
    required this.hostController,
    required this.portController,
    required this.usernameController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Custom Node'),
      ),
      body: BlocBuilder<VpnBloc, VpnState>(
        builder: (context, vpn) {
          final bloc = context.read<VpnBloc>();
          return Padding(
            padding: const EdgeInsets.all(20),
            child: CustomNodeSettings(
              enabled: vpn.useCustomConfig,
              onEnabledChanged: (v) => bloc.add(UseCustomConfigChanged(v)),
              hostController: hostController,
              portController: portController,
              usernameController: usernameController,
              passwordController: passwordController,
            ),
          );
        },
      ),
    );
  }
}

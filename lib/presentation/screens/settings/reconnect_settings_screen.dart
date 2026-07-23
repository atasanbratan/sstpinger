import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/vpn/vpn_bloc.dart';
import '../../widgets/profile_settings/reconnect_settings_card.dart';

/// Bottom-sheet content for Settings → Network → Reconnection.
class ReconnectSettingsScreen extends StatelessWidget {
  const ReconnectSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, vpn) {
        final bloc = context.read<VpnBloc>();
        return ReconnectSettingsCard(
          retryCount: vpn.reconnectRetryCount,
          onRetryCountChanged: (v) => bloc.add(ReconnectRetryCountChanged(v)),
          retryIntervalSeconds: vpn.reconnectRetryIntervalSeconds,
          onRetryIntervalChanged: (v) =>
              bloc.add(ReconnectRetryIntervalChanged(v)),
          onPersist: () => bloc.add(const ReconnectSettingsPersistRequested()),
        );
      },
    );
  }
}

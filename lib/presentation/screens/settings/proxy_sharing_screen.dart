import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/vpn/vpn_bloc.dart';
import '../../widgets/profile_settings/proxy_sharing_card.dart';

/// Bottom-sheet content for Settings → Network → Proxy sharing.
class ProxySharingScreen extends StatelessWidget {
  const ProxySharingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, vpn) {
        final bloc = context.read<VpnBloc>();
        return ProxySharingCard(
          enabled: vpn.proxySharingEnabled,
          onEnabledChanged: (v) => bloc.add(ProxySharingToggled(v)),
          port: vpn.proxySharingPort,
          onPortChanged: (v) => bloc.add(ProxySharingPortChanged(v)),
          onPersist: () =>
              bloc.add(const ProxySharingSettingsPersistRequested()),
        );
      },
    );
  }
}

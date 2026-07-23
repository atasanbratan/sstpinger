import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/vpn/vpn_bloc.dart';
import '../../widgets/profile_settings/softether_natt_card.dart';

/// Bottom-sheet content for Settings → Network → SoftEther transport
/// (desktop only).
class SoftEtherNattScreen extends StatelessWidget {
  const SoftEtherNattScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, vpn) {
        final bloc = context.read<VpnBloc>();
        return SoftEtherNatTCard(
          disableNatT: vpn.softEtherDisableNatT,
          onDisableNatTChanged: (v) =>
              bloc.add(SoftEtherDisableNatTChanged(v)),
          retryWaitSeconds: vpn.softEtherNatTRetryWaitSeconds,
          onRetryWaitChanged: (v) =>
              bloc.add(SoftEtherNatTRetryWaitChanged(v)),
          onPersist: () =>
              bloc.add(const SoftEtherNatTSettingsPersistRequested()),
        );
      },
    );
  }
}

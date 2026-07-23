import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/vpn/vpn_bloc.dart';
import '../../widgets/profile_settings/protocol_card.dart';

/// Bottom-sheet content for Settings → Network → Protocol (desktop only).
class ProtocolScreen extends StatelessWidget {
  const ProtocolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, vpn) {
        final bloc = context.read<VpnBloc>();
        return ProtocolCard(
          selected: vpn.protocol,
          onChanged: (p) => bloc.add(ProtocolChanged(p)),
        );
      },
    );
  }
}

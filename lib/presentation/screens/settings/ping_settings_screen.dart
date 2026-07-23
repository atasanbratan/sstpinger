import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/vpn/vpn_bloc.dart';
import '../../widgets/profile_settings/ping_mode_card.dart';
import '../../widgets/profile_settings/ping_settings_card.dart';

/// Bottom-sheet content for Settings → Network → Ping settings.
class PingSettingsScreen extends StatelessWidget {
  const PingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, vpn) {
        final bloc = context.read<VpnBloc>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PingSettingsCard(
              timeoutSeconds: vpn.pingTimeoutSeconds,
              onTimeoutChanged: (v) => bloc.add(PingTimeoutChanged(v)),
              batchSize: vpn.pingBatchSize,
              onBatchSizeChanged: (v) => bloc.add(PingBatchSizeChanged(v)),
              onPersist: () => bloc.add(const PingSettingsPersistRequested()),
            ),
            const SizedBox(height: 10),
            PingModeCard(
              mode: vpn.pingMode,
              onChanged: (m) => bloc.add(PingModeChanged(m)),
            ),
          ],
        );
      },
    );
  }
}

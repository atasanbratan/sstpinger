import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/vpn/vpn_bloc.dart';
import '../../widgets/profile_settings/fetch_count_card.dart';

/// Bottom-sheet content for Settings → Network → Server fetch count.
class FetchCountScreen extends StatelessWidget {
  const FetchCountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VpnBloc, VpnState>(
      builder: (context, vpn) {
        final bloc = context.read<VpnBloc>();
        return FetchCountCard(
          count: vpn.fetchServerCount,
          onChanged: (v) => bloc.add(FetchServerCountChanged(v)),
          onPersist: () => bloc.add(const FetchServerCountPersistRequested()),
        );
      },
    );
  }
}

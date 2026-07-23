import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'onboarding/subscription_section.dart';
import '../bloc/vpn/vpn_bloc.dart';
import '../theme/app_colors.dart';

/// Pushed from Settings for an already-onboarded user extending/renewing via
/// USDT — the same [SubscriptionSection] the onboarding gate uses, wrapped in
/// its own scaffold and a listener that pops on success.
class SubscriptionRenewScreen extends StatelessWidget {
  final VoidCallback onCompleted;

  const SubscriptionRenewScreen({super.key, required this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VpnBloc, VpnState>(
      listenWhen: (prev, curr) =>
          curr.actionResult != null &&
          curr.actionResult!.id != prev.actionResult?.id &&
          curr.actionResult!.kind == VpnActionKind.subscription,
      listener: (context, state) {
        if (state.actionResult!.success) onCompleted();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Subscribe with USDT'),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.gradientTop, AppColors.gradientBottom],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: const SubscriptionSection(),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'onboarding/activation_section.dart';
import 'onboarding/subscription_section.dart';
import 'onboarding/trial_cta.dart';
import '../bloc/vpn/vpn_bloc.dart';
import '../theme/app_colors.dart';

/// The onboarding gate: every path to get access lives on one screen — a
/// free trial (new installs only), an activation code, or a USDT
/// subscription. Swapped out automatically by the parent once
/// `VpnState.needsOnboarding` goes false, so nothing here needs to know
/// which path succeeded.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isStartingTrial = context.select<VpnBloc, bool>(
      (b) => b.state.isStartingTrial,
    );
    // A brand-new install (no username yet) is still eligible for the trial;
    // once used, the username persists and only the code/subscription paths
    // are offered.
    final isTrialEligible = context.select<VpnBloc, bool>(
      (b) => b.state.username.isEmpty,
    );

    return Scaffold(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Image.asset('assets/logo/logo.png', width: 80, height: 80),
                const SizedBox(height: 16),
                const Text(
                  'SSTP SHIELD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your Secure Gateway to SSTP VPN Nodes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                if (isTrialEligible) ...[
                  TrialCta(
                    isStartingTrial: isStartingTrial,
                    onStart: () => context
                        .read<VpnBloc>()
                        .add(const FreeTrialRequested()),
                  ),
                  const SizedBox(height: 20),
                  _orDivider('or use one of these'),
                  const SizedBox(height: 20),
                ],
                _sectionLabel('Have an activation code?'),
                const SizedBox(height: 10),
                const ActivationSection(),
                const SizedBox(height: 24),
                _orDivider('or subscribe with USDT'),
                const SizedBox(height: 20),
                const SubscriptionSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _orDivider(String label) => Row(
    children: [
      const Expanded(child: Divider(color: AppColors.divider)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label, style: const TextStyle(color: AppColors.textMuted)),
      ),
      const Expanded(child: Divider(color: AppColors.divider)),
    ],
  );
}

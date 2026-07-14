import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/subscription_config.dart';
import '../../../core/app_colors.dart';
import '../view_models/vpn_view_model.dart';

/// Onboarding for the foreign variant: the user pays a USDT subscription
/// (BEP20 / TRC20), pastes the transaction hash, and the backend verifies it
/// on-chain before unlocking access.
class SubscriptionScreen extends StatefulWidget {
  final VpnViewModel viewModel;

  /// Called after a successful trial start or purchase. Used when the screen is
  /// pushed as an in-app upgrade (to pop it); null when it acts as the gate,
  /// where the parent swaps the screen automatically.
  final VoidCallback? onCompleted;

  const SubscriptionScreen({
    super.key,
    required this.viewModel,
    this.onCompleted,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final TextEditingController _txHashController = TextEditingController();
  SubscriptionNetwork _network = SubscriptionConfig.networks.first;

  @override
  void dispose() {
    _txHashController.dispose();
    super.dispose();
  }

  Future<void> _copyAddress() async {
    await Clipboard.setData(ClipboardData(text: _network.walletAddress));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied', style: TextStyle(fontFamily: 'Outfit')),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startTrial() async {
    final ok = await widget.viewModel.startFreeTrial();
    if (ok && mounted) widget.onCompleted?.call();
  }

  Future<void> _submit() async {
    final txHash = _txHashController.text.trim();
    if (txHash.isEmpty) {
      widget.viewModel.onErrorMessage?.call('Paste your transaction hash first.');
      return;
    }
    final ok = await widget.viewModel.submitSubscription(
      network: _network.id,
      txHash: txHash,
    );
    // As the gate, the parent swaps the screen; as an in-app upgrade, pop it.
    if (ok && mounted) widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = widget.viewModel.isSubmittingSubscription;
    final isStartingTrial = widget.viewModel.isStartingTrial;
    // A brand-new install (no username yet) is still eligible for the trial;
    // once used, the username persists and only the paid flow is offered.
    final isTrialEligible = widget.viewModel.username.isEmpty;

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
                Text(
                  isTrialEligible
                      ? 'Start free, or subscribe with USDT'
                      : 'Subscribe with USDT',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                if (isTrialEligible) ...[
                  _trialCta(isStartingTrial),
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Expanded(child: Divider(color: AppColors.divider)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or pay now',
                            style: TextStyle(color: AppColors.textMuted)),
                      ),
                      Expanded(child: Divider(color: AppColors.divider)),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                _sectionLabel('1 · Choose a plan'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: SubscriptionConfig.plans
                      .map((p) => _PlanChip(plan: p))
                      .toList(),
                ),
                const SizedBox(height: 24),
                _sectionLabel('2 · Pay to this address'),
                const SizedBox(height: 10),
                _networkSelector(),
                const SizedBox(height: 12),
                _addressBox(),
                const SizedBox(height: 24),
                _sectionLabel('3 · Confirm your payment'),
                const SizedBox(height: 10),
                TextField(
                  controller: _txHashController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Transaction hash',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.surfaceDeep,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.surfaceDeep,
                          ),
                        )
                      : const Text('Verify payment'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Verification is automatic and on-chain. It may take a few '
                  'minutes for the network to confirm your transaction.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trialCta(bool isStartingTrial) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        children: [
          Text(
            'Try free for ${SubscriptionConfig.trialDays} days',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No payment required. Full access during the trial.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isStartingTrial ? null : _startTrial,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.surfaceDeep,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isStartingTrial
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.surfaceDeep,
                      ),
                    )
                  : const Text('Start free trial'),
            ),
          ),
        ],
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

  Widget _networkSelector() {
    return Row(
      children: SubscriptionConfig.networks.map((n) {
        final selected = n.id == _network.id;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: n == SubscriptionConfig.networks.first ? 10 : 0,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _network = n),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.surfaceSelected
                      : AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.accent
                        : AppColors.accentBorderFaint,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      n.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.chain,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _addressBox() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _copyAddress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentBorderFaint),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _network.walletAddress,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.copy_rounded, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final SubscriptionPlan plan;

  const _PlanChip({required this.plan});

  @override
  Widget build(BuildContext context) {
    final months = plan.months;
    final label = months % 12 == 0
        ? '${months ~/ 12} yr'
        : '$months mo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentBorderFaint),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\$${plan.priceUsdt}',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

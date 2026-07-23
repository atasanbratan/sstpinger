import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/subscription_config.dart';
import '../../bloc/vpn/vpn_bloc.dart';
import '../../theme/app_colors.dart';

/// "Subscribe with USDT" onboarding path: pick a plan, pay to the shown
/// address (BEP20/TRC20, with a QR code), then confirm with the transaction
/// hash for on-chain verification.
class SubscriptionSection extends StatefulWidget {
  const SubscriptionSection({super.key});

  @override
  State<SubscriptionSection> createState() => _SubscriptionSectionState();
}

class _SubscriptionSectionState extends State<SubscriptionSection> {
  final TextEditingController _txHashController = TextEditingController();
  SubscriptionNetwork _network = SubscriptionConfig.networks.first;
  SubscriptionPlan _plan = SubscriptionConfig.plans.first;

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

  void _submit() {
    final txHash = _txHashController.text.trim();
    if (txHash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Paste your transaction hash first.',
            style: TextStyle(fontFamily: 'Outfit'),
          ),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    context.read<VpnBloc>().add(
      SubscriptionSubmitted(network: _network.id, txHash: txHash),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.select<VpnBloc, bool>(
      (b) => b.state.isSubmittingSubscription,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('1 · Choose a plan'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: SubscriptionConfig.plans
              .map(
                (p) => _PlanChip(
                  plan: p,
                  selected: p.priceUsdt == _plan.priceUsdt,
                  onTap: () => setState(() => _plan = p),
                ),
              )
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
          'Verification is automatic and on-chain. It may take a '
          'few minutes for the network to confirm your transaction.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentBorderFaint),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: QrImageView(
              // Keyed so switching BEP20 <-> TRC20 rebuilds the QR image
              // instead of reusing a cached render of the previous address.
              key: ValueKey(_network.walletAddress),
              data: _network.walletAddress,
              size: 160,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _copyAddress,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _network.walletAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy_rounded,
                      color: AppColors.accent, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanChip({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final months = plan.months;
    final label = months % 12 == 0 ? '${months ~/ 12} yr' : '$months mo';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceSelected : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.accentBorderFaint,
          ),
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
      ),
    );
  }
}

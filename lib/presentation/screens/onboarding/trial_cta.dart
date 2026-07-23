import 'package:flutter/material.dart';

import '../../../core/config/subscription_config.dart';
import '../../theme/app_colors.dart';

/// The free-trial call-to-action, shown to any brand-new install (no
/// username yet) alongside the other onboarding paths.
class TrialCta extends StatelessWidget {
  final bool isStartingTrial;
  final VoidCallback onStart;

  const TrialCta({
    super.key,
    required this.isStartingTrial,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
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
              onPressed: isStartingTrial ? null : onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.surfaceDeep,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
}

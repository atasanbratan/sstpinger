import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Renew-subscription actions: paste a new activation code, load one from a
/// file, or subscribe/extend with USDT — all three always offered.
class RenewButtons extends StatelessWidget {
  final VoidCallback onRenew;
  final VoidCallback? onRenewFromFile;
  final VoidCallback onSubscribe;

  const RenewButtons({
    super.key,
    required this.onRenew,
    this.onRenewFromFile,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onRenew,
            icon: const Icon(Icons.autorenew, size: 18),
            label: const Text('RENEW ACTIVATION CODE'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accentBorder),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        if (onRenewFromFile != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRenewFromFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('RENEW FROM FILE'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accentBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSubscribe,
            icon: const Icon(Icons.currency_bitcoin_rounded, size: 18),
            label: const Text('SUBSCRIBE WITH USDT'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accentBorder),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

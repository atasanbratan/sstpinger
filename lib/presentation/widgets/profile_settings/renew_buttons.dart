import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Renew-subscription actions: the primary renew button, plus an optional
/// second one for loading an activation-code file (hidden for the foreign
/// variant, which renews via payment instead).
class RenewButtons extends StatelessWidget {
  final VoidCallback onRenew;
  final String renewLabel;
  final VoidCallback? onRenewFromFile;

  const RenewButtons({
    super.key,
    required this.onRenew,
    required this.renewLabel,
    this.onRenewFromFile,
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
            label: Text(renewLabel),
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
      ],
    );
  }
}

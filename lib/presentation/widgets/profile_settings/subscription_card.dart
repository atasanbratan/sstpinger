import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// Expiry date and last server-list fetch time.
class SubscriptionCard extends StatelessWidget {
  final bool isExpired;
  final DateTime? expireTime;
  final DateTime? lastFetchTime;

  const SubscriptionCard({
    super.key,
    required this.isExpired,
    required this.expireTime,
    required this.lastFetchTime,
  });

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final local = date.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${_months[local.month - 1]} ${local.day}, ${local.year}  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final Color expiryColor = isExpired ? AppColors.error : AppColors.accent;

    return SettingsCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isExpired
                    ? Icons.error_outline
                    : Icons.workspace_premium_outlined,
                color: expiryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isExpired ? 'Expired on' : 'Expires on',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                    Text(
                      _formatDate(expireTime),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: expiryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              const Icon(Icons.update, color: Colors.white54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server list last updated',
                      style: TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                    Text(
                      _formatDate(lastFetchTime),
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

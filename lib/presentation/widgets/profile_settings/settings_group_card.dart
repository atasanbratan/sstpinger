import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// Groups several [SettingsRow]s (or any row-shaped widget) inside one
/// rounded card with a hairline divider between consecutive rows — the
/// "N rows under one section header" shape used throughout the settings
/// screen, replacing the old one-card-per-concern layout.
class SettingsGroupCard extends StatelessWidget {
  final List<Widget> rows;

  const SettingsGroupCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              const Divider(color: AppColors.divider, height: 1, indent: 52),
          ],
        ],
      ),
    );
  }
}

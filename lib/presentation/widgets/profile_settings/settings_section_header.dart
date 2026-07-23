import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The small bold caption above each settings section ("ACCOUNT",
/// "NETWORK", ...). Pulled out because the same style was repeated
/// verbatim at every section boundary in the settings sheet.
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.textFaint,
      ),
    );
  }
}

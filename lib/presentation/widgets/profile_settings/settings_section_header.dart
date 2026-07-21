import 'package:flutter/material.dart';

/// The small bold caption above each settings section ("USER PROFILE",
/// "SUBSCRIPTION", ...). Pulled out because the same style was repeated
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
        color: Colors.white38,
      ),
    );
  }
}

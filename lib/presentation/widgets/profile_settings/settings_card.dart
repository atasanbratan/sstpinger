import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Shared chrome for a settings section: rounded card + padding. Every card
/// in the settings sheet wraps its content in this so the visual language
/// (radius, background, padding) lives in one place instead of being
/// repeated at every call site.
class SettingsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SettingsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: padding, child: child),
    );
  }
}

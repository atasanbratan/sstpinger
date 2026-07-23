import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Shared chrome for the settings drill-downs that show as a bottom sheet
/// instead of a pushed screen: drag handle + title, then the caller's
/// content (typically an unchanged `*Card` widget).
Future<void> showSettingsBottomSheet(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

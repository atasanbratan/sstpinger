import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A one-time, fully dismissible nudge offering to link a Google account after
/// a trial/subscription success, shown by `MainVpnScreen` in response to
/// `VpnState.googleLinkNudge`. Unlike [AppUpdateDialog] this never blocks —
/// both the barrier and "Maybe later" dismiss it, since sign-in is a
/// convenience (recoverable access after a reinstall), never a requirement.
class GoogleLinkNudgeDialog extends StatelessWidget {
  final VoidCallback onSignIn;

  const GoogleLinkNudgeDialog({super.key, required this.onSignIn});

  static Future<void> show(BuildContext context, {required VoidCallback onSignIn}) {
    return showDialog<void>(
      context: context,
      builder: (_) => GoogleLinkNudgeDialog(onSignIn: onSignIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Keep your access safe'),
      content: Text(
        "You're all set — no account needed. But if you ever reinstall the "
        'app or switch devices, signing in with Google lets you get your '
        'access back instantly.',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onSignIn();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.background,
          ),
          child: const Text('Sign in with Google'),
        ),
      ],
    );
  }
}

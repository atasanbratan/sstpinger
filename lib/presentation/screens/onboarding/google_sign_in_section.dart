import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/vpn/vpn_bloc.dart';
import '../../theme/app_colors.dart';

/// Onboarding entry for Google Sign-In. Shows a "Continue with Google" button
/// when the platform supports it and the user isn't signed in; once signed in,
/// shows the account email instead (the trial/subscription paths below then
/// attach to that account).
class GoogleSignInSection extends StatelessWidget {
  const GoogleSignInSection({super.key});

  @override
  Widget build(BuildContext context) {
    final available = context.select<VpnBloc, bool>(
      (b) => b.state.googleSignInAvailable,
    );
    if (!available) return const SizedBox.shrink();

    final hasSession = context.select<VpnBloc, bool>((b) => b.state.hasSession);
    if (hasSession) {
      final email = context.select<VpnBloc, String>((b) => b.state.email);
      return _SignedInChip(email: email);
    }

    final isSigningIn = context.select<VpnBloc, bool>(
      (b) => b.state.isSigningInWithGoogle,
    );

    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isSigningIn
            ? null
            : () =>
                context.read<VpnBloc>().add(const GoogleSignInRequested()),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: isSigningIn
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login, size: 20),
        label: Text(
          isSigningIn ? 'Signing in…' : 'Continue with Google',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SignedInChip extends StatelessWidget {
  final String email;
  const _SignedInChip({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.connected, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              email.isEmpty ? 'Signed in with Google' : 'Signed in as $email',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () =>
                context.read<VpnBloc>().add(const SignOutRequested()),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

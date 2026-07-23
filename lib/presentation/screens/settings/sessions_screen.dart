import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/formatters.dart';
import '../../../domain/entities/user_session.dart';
import '../../bloc/vpn/vpn_bloc.dart';
import '../../theme/app_colors.dart';

/// Lists the signed-in account's registered device sessions and lets the user
/// revoke any of them. Replaces the old fixed one-per-platform device slots:
/// a user may hold several concurrent sessions (up to the backend's cap).
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<VpnBloc>().add(const SessionsRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'ACTIVE SESSIONS',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<VpnBloc>().add(const SessionsRequested()),
          ),
        ],
      ),
      body: BlocBuilder<VpnBloc, VpnState>(
        buildWhen: (a, b) =>
            a.sessions != b.sessions ||
            a.isLoadingSessions != b.isLoadingSessions,
        builder: (context, vpn) {
          if (vpn.isLoadingSessions && vpn.sessions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vpn.sessions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No active sessions.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vpn.sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _SessionTile(session: vpn.sessions[i]),
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final UserSession session;
  const _SessionTile({required this.session});

  IconData get _platformIcon => switch (session.platform) {
        'android' => Icons.android,
        'ios' || 'macos' => Icons.apple,
        'windows' => Icons.window,
        'linux' => Icons.terminal,
        _ => Icons.devices_other,
      };

  @override
  Widget build(BuildContext context) {
    final label = session.platform.isEmpty
        ? 'Unknown device'
        : session.platform[0].toUpperCase() + session.platform.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(_platformIcon, color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last seen ${Formatters.date(session.lastSeenAt)}'
                  '${session.active ? '' : ' · disabled'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _confirmRevoke(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRevoke(BuildContext context) async {
    final bloc = context.read<VpnBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Revoke session?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'That device will be signed out and must sign in again.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok == true) {
      bloc.add(SessionRevoked(session.id));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/connection/connection_bloc.dart';
import '../../bloc/vpn/vpn_bloc.dart';
import '../../theme/app_colors.dart';
import 'server_count_label.dart';

/// The header riding above the server list: title + count, the search field
/// with ping-all/fetch actions, and a ping-progress bar while a ping is
/// running.
class ServersHeaderBlock extends StatelessWidget {
  final VpnState vpn;
  final TextEditingController searchController;

  const ServersHeaderBlock({
    super.key,
    required this.vpn,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Servers',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            ServerCountLabel(vpn),
          ],
        ),
        const SizedBox(height: 10),
        _SearchRow(vpn: vpn, controller: searchController),
        if (vpn.isPinging) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: vpn.pingTotal == 0 ? null : vpn.pingProgress / vpn.pingTotal,
              minHeight: 3,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ],
      ],
    );
  }
}

/// Search field with the ping-all and fetch actions beside it, as in Happ's
/// server pane.
class _SearchRow extends StatelessWidget {
  final VpnState vpn;
  final TextEditingController controller;

  const _SearchRow({required this.vpn, required this.controller});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionBloc, VpnConnectionState>(
      builder: (context, conn) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Type here to search',
                hintStyle: const TextStyle(color: AppColors.textFaint),
                suffixIcon: vpn.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        onPressed: () {
                          controller.clear();
                          context.read<VpnBloc>().add(
                            const SearchQueryChanged(''),
                          );
                        },
                      )
                    : const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentBorder),
                ),
              ),
              onChanged: (q) =>
                  context.read<VpnBloc>().add(SearchQueryChanged(q)),
            ),
          ),
          const SizedBox(width: 8),
          // Ping every server and sort fastest-first.
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: conn.isConnected
                  ? 'Disconnect to ping servers'
                  : 'Ping all and sort',
              onPressed: vpn.isPinging
                  ? null
                  : () => context.read<VpnBloc>().add(
                      PingRequested(isConnected: conn.isConnected),
                    ),
              icon: vpn.isPinging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : Icon(
                      Icons.speed_rounded,
                      color: conn.isConnected
                          ? AppColors.textFaint
                          : AppColors.accent,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Fetch the latest server list from the backend.
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: 'Fetch latest servers',
              onPressed: vpn.isFetchingServers
                  ? null
                  : () => context.read<VpnBloc>().add(
                      const ServersFetchRequested(),
                    ),
              icon: vpn.isFetchingServers
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      color: AppColors.accent,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

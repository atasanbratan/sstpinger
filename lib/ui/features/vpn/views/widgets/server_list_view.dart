import 'package:flutter/material.dart';

import '../../../../../core/utils/country_flag.dart';
import '../../../../../data/models/vpn_server.dart';
import '../../../../core/app_colors.dart';
import '../../view_models/vpn_view_model.dart';

class ServerListView extends StatefulWidget {
  final VpnViewModel viewModel;
  final VoidCallback onEditUsername;

  const ServerListView({
    super.key,
    required this.viewModel,
    required this.onEditUsername,
  });

  @override
  State<ServerListView> createState() => _ServerListViewState();
}

class _ServerListViewState extends State<ServerListView> {
  // Countries whose group is currently expanded. Groups start collapsed.
  final Set<String> _expanded = {};

  VpnViewModel get viewModel => widget.viewModel;
  VoidCallback get onEditUsername => widget.onEditUsername;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isFetchingServers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (viewModel.serverFetchError != null) {
      return Card(
        color: AppColors.errorSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'Fetch Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                viewModel.serverFetchError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: viewModel.fetchServers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('RETRY'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onEditUsername,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('CHANGE USERNAME'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final filtered = viewModel.getFilteredServers();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            'No servers match your search filter.',
            style: TextStyle(color: AppColors.textFaint),
          ),
        ),
      );
    }

    // Group servers by country, preserving the order they arrive in so a
    // ping-sorted list keeps its fastest-first ordering within each group.
    final grouped = <String, List<VpnServer>>{};
    for (final server in filtered) {
      grouped.putIfAbsent(server.country, () => []).add(server);
    }

    // Order the country groups alphabetically for a predictable layout.
    final countries = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final bookmarks = viewModel.bookmarkedServers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bookmarks.isNotEmpty) _buildBookmarksSection(context, bookmarks),
        for (int i = 0; i < countries.length; i++) ...[
          _buildCountryHeader(
            country: countries[i],
            servers: grouped[countries[i]]!,
            topPadding: i == 0 && bookmarks.isEmpty ? 0 : 8,
          ),
          if (_expanded.contains(countries[i]))
            for (final server in grouped[countries[i]]!)
              _buildServerTile(context, server),
        ],
      ],
    );
  }

  Widget _buildBookmarksSection(
    BuildContext context,
    List<VpnServer> bookmarks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(
                Icons.bookmark_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              const Text(
                'BOOKMARKS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              _CountBadge(label: '${bookmarks.length}', color: AppColors.accent),
              const Spacer(),
              // Ping just the bookmarked servers.
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: viewModel.isPinging
                    ? null
                    : viewModel.pingBookmarkedServers,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      viewModel.isPinging
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : Icon(
                              Icons.speed,
                              size: 16,
                              color: viewModel.isConnected
                                  ? AppColors.textFaint
                                  : AppColors.accent,
                            ),
                      const SizedBox(width: 6),
                      Text(
                        'Ping',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: viewModel.isConnected
                              ? AppColors.textFaint
                              : AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final server in bookmarks) _buildServerTile(context, server),
        const SizedBox(height: 8),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCountryHeader({
    required String country,
    required List<VpnServer> servers,
    required double topPadding,
  }) {
    final countryShort = servers.isNotEmpty ? servers.first.countryShort : '';
    final isExpanded = _expanded.contains(country);
    final reachedCount = servers.where((s) => s.ping != null).length;

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expanded.remove(country);
            } else {
              _expanded.add(country);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(
                countryFlagEmoji(countryShort),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  country.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.grey[400],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Reached (successfully pinged) server count for this group.
              if (reachedCount > 0) ...[
                _CountBadge(
                  label: '$reachedCount',
                  color: AppColors.pingGood,
                  icon: Icons.wifi_tethering_rounded,
                ),
                const SizedBox(width: 6),
              ],
              // Total server count for this group.
              _CountBadge(
                label: '${servers.length}',
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textFaint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerTile(BuildContext context, VpnServer server) {
    final bool isSelected =
        !viewModel.useCustomConfig &&
        viewModel.selectedServer?.id == server.id;
    final bool isBookmarked = viewModel.isBookmarked(server);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: () => viewModel.selectServer(server),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.surfaceSelected
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDeep,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  countryFlagEmoji(server.countryShort),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.country.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.hostname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Node #${server.id}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.cyan[200],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.textFaint,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sessions: ${server.sessions}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (server.ping != null)
                Text(
                  '${server.ping} ms',
                  style: TextStyle(
                    color: _pingColor(server.ping!),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  '--',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11),
                ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => viewModel.toggleBookmark(server),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isBookmarked
                        ? AppColors.accent
                        : AppColors.textFaint,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.accent,
                  size: 22,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textFaint,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Latency bucket color: fast (<80ms), medium (<150ms), slow otherwise.
  static Color _pingColor(int ping) {
    if (ping < 80) return AppColors.pingGood;
    if (ping < 150) return AppColors.pingMedium;
    return AppColors.pingBad;
  }
}

/// Small rounded pill showing a count, optionally prefixed with an icon.
class _CountBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _CountBadge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/country_flag.dart';
import '../../domain/entities/vpn_server.dart';
import '../bloc/connection/connection_bloc.dart';
import '../bloc/vpn/vpn_bloc.dart';
import '../theme/app_colors.dart';
import 'rounded_list_tile.dart';
import 'server_group_header.dart';
import 'server_list_item.dart';
import 'server_ping_action.dart';
import 'server_row.dart';
import 'server_tab_bar.dart';

/// The server picker: a scroll owner (so the list can be virtualized) holding
/// the caller-supplied [header] (server count / search / ping-progress), the
/// tab bar (Servers · Bookmarks · Recents), and the active tab's pane.
class ServerListView extends StatefulWidget {
  final ScrollController scrollController;
  final Widget header;

  const ServerListView({
    super.key,
    required this.scrollController,
    required this.header,
  });

  @override
  State<ServerListView> createState() => _ServerListViewState();
}

class _ServerListViewState extends State<ServerListView> {
  // Country groups currently expanded (Servers tab). They start collapsed.
  final Set<String> _expanded = {};

  ServerTab _tab = ServerTab.servers;

  static const double _groupGap = 10;

  void _toggle(String key) => setState(() {
    if (!_expanded.remove(key)) _expanded.add(key);
  });

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnBloc>().state;
    final isConnected = context.watch<ConnectionBloc>().state.isConnected;

    return CustomScrollView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          sliver: SliverToBoxAdapter(child: widget.header),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          sliver: SliverToBoxAdapter(
            child: ServerTabBar(
              activeTab: _tab,
              onTabSelected: (tab) => setState(() => _tab = tab),
              serversCount: vpn.servers.length,
              bookmarksCount: vpn.bookmarkedServers.length,
              recentsCount: vpn.recentServers.length,
              serversFlatView: vpn.serversFlatView,
              onToggleFlatView: () => context
                  .read<VpnBloc>()
                  .add(ServersViewModeChanged(!vpn.serversFlatView)),
            ),
          ),
        ),
        if (vpn.isFetchingServers)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          )
        else
          ..._buildActiveTab(context, vpn, isConnected),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // -- panes -----------------------------------------------------------------

  List<Widget> _buildActiveTab(
    BuildContext context,
    VpnState vpn,
    bool isConnected,
  ) {
    final query = vpn.searchQuery;
    switch (_tab) {
      case ServerTab.servers:
        return _buildServersTab(context, vpn);
      case ServerTab.bookmarks:
        return _buildFlatList(
          context,
          vpn,
          _filter(vpn.bookmarkedServers, query),
          empty: 'No bookmarks yet.\nTap the bookmark icon on a server to pin it.',
          pingAction: PingAction(
            isPinging: vpn.isPinging,
            isConnected: isConnected,
            onPressed: () => context.read<VpnBloc>().add(
              BookmarkPingRequested(isConnected: isConnected),
            ),
          ),
        );
      case ServerTab.recents:
        return _buildFlatList(
          context,
          vpn,
          _filter(vpn.recentServers, query),
          empty: 'No recent servers yet.\nConnect to a server and it will show here.',
        );
    }
  }

  /// The Servers pane: country-grouped accordion, or a flat ping-sorted list —
  /// both honouring the search filter.
  List<Widget> _buildServersTab(BuildContext context, VpnState vpn) {
    final filtered = vpn.filteredServers;
    if (filtered.isEmpty) {
      return [_emptyStateSliver('No servers match your search filter.')];
    }

    if (vpn.serversFlatView) {
      // One flat list, fastest first; unreachable (no ping) sink to the bottom.
      final sorted = List<VpnServer>.from(filtered)
        ..sort((a, b) => (a.ping ?? 1 << 30).compareTo(b.ping ?? 1 << 30));
      return [_itemsSliver(context, vpn, _flatItems(sorted))];
    }

    // Group by country, preserving arrival order so a ping-sorted list keeps its
    // fastest-first ordering inside each group.
    final grouped = <String, List<VpnServer>>{};
    for (final server in filtered) {
      grouped.putIfAbsent(server.country, () => []).add(server);
    }
    final countries = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final items = <ServerListItem>[];
    for (final country in countries) {
      final servers = grouped[country]!;
      final expanded = _expanded.contains(country);
      items.add(
        ServerHeaderItem(
          country: country,
          servers: servers,
          isExpanded: expanded,
          bottomGap: expanded ? 0 : _groupGap,
        ),
      );
      if (expanded) {
        for (var i = 0; i < servers.length; i++) {
          final isLast = i == servers.length - 1;
          items.add(
            ServerRowItem(
              server: servers[i],
              roundBottom: isLast,
              bottomGap: isLast ? _groupGap : 0,
            ),
          );
        }
      }
    }
    return [_itemsSliver(context, vpn, items)];
  }

  /// A flat, rounded list of rows for the Bookmarks / Recents panes.
  List<Widget> _buildFlatList(
    BuildContext context,
    VpnState vpn,
    List<VpnServer> servers, {
    required String empty,
    Widget? pingAction,
  }) {
    if (servers.isEmpty) return [_emptyStateSliver(empty)];
    return [
      if (pingAction != null)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: Align(alignment: Alignment.centerRight, child: pingAction),
          ),
        ),
      _itemsSliver(context, vpn, _flatItems(servers)),
    ];
  }

  List<ServerListItem> _flatItems(List<VpnServer> servers) => [
    for (var i = 0; i < servers.length; i++)
      ServerRowItem(
        server: servers[i],
        roundTop: i == 0,
        roundBottom: i == servers.length - 1,
        bottomGap: 0,
      ),
  ];

  Widget _itemsSliver(
    BuildContext context,
    VpnState vpn,
    List<ServerListItem> items,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _buildItem(context, vpn, items[index]),
      ),
    );
  }

  Widget _buildItem(BuildContext context, VpnState vpn, ServerListItem item) {
    final tile = switch (item) {
      ServerHeaderItem h => ServerGroupHeader(
        leading: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceDeep,
          ),
          child: Text(
            countryFlagEmoji(h.servers.first.countryShort),
            style: const TextStyle(fontSize: 15),
          ),
        ),
        title: h.country.toUpperCase(),
        subtitle: _subtitle(h.servers),
        reachable: _reachable(h.servers),
        isExpanded: h.isExpanded,
        roundBottom: !h.isExpanded,
        onToggle: () => _toggle(h.country),
      ),
      ServerRowItem r => RoundedListTile(
        roundTop: r.roundTop,
        roundBottom: r.roundBottom,
        child: _row(
          context,
          vpn,
          r.server,
          showBottomDivider: !r.roundBottom,
        ),
      ),
    };
    return item.bottomGap > 0
        ? Padding(padding: EdgeInsets.only(bottom: item.bottomGap), child: tile)
        : tile;
  }

  Widget _emptyStateSliver(String message) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textFaint),
        ),
      ),
    ),
  );

  /// Filters a curated list (bookmarks/recents) by the active search query.
  List<VpnServer> _filter(List<VpnServer> servers, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return servers;
    return servers
        .where(
          (s) =>
              s.country.toLowerCase().contains(q) ||
              s.hostname.toLowerCase().contains(q),
        )
        .toList();
  }

  /// The base "12 servers" clause; the reachable count is appended in green by
  /// [ServerGroupHeader] via [_reachable].
  String _subtitle(List<VpnServer> servers) {
    final plural = servers.length == 1 ? 'server' : 'servers';
    return '${servers.length} $plural';
  }

  int _reachable(List<VpnServer> servers) =>
      servers.where((s) => s.ping != null).length;

  Widget _row(
    BuildContext context,
    VpnState vpn,
    VpnServer server, {
    bool showBottomDivider = false,
  }) {
    return ServerRow(
      server: server,
      isSelected:
          !vpn.useCustomConfig && vpn.selectedServer?.endpoint == server.endpoint,
      isBookmarked: vpn.isBookmarked(server),
      onTap: () => context.read<VpnBloc>().add(ServerSelected(server)),
      onBookmarkToggle: () =>
          context.read<VpnBloc>().add(BookmarkToggled(server)),
      showBottomDivider: showBottomDivider,
    );
  }
}

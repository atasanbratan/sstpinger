import '../../domain/entities/vpn_server.dart';

/// A single entry in the flattened, lazily-built server list. Grouping and
/// filtering still cost an O(n) pass to build this list, but — unlike an
/// eagerly-built `Column` of every row — only the entries actually near the
/// viewport ever get turned into real row widgets, via `SliverList.builder`.
/// This matters because a server list can run into the thousands.
sealed class ServerListItem {
  /// Vertical gap to leave below this item (used to separate one country
  /// group's "card" from the next).
  final double bottomGap;
  const ServerListItem({required this.bottomGap});
}

class ServerHeaderItem extends ServerListItem {
  final String country;
  final List<VpnServer> servers;
  final bool isExpanded;
  const ServerHeaderItem({
    required this.country,
    required this.servers,
    required this.isExpanded,
    required super.bottomGap,
  });
}

class ServerRowItem extends ServerListItem {
  final VpnServer server;
  final bool roundTop;
  final bool roundBottom;
  const ServerRowItem({
    required this.server,
    this.roundTop = false,
    this.roundBottom = false,
    required super.bottomGap,
  });
}

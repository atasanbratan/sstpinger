import '../../../domain/entities/vpn_server.dart';

/// Pure list transforms for [ServerListView] — sorting, grouping, filtering —
/// kept separate from the widget tree so they're plain, testable functions.

/// One flat list, fastest first; unreachable (no ping) sink to the bottom.
List<VpnServer> sortedByPing(List<VpnServer> servers) {
  final sorted = List<VpnServer>.from(servers)
    ..sort((a, b) => (a.ping ?? 1 << 30).compareTo(b.ping ?? 1 << 30));
  return sorted;
}

/// Groups by country (arrival order preserved within each group, so a
/// ping-sorted input keeps its fastest-first ordering inside each group),
/// keyed by country name sorted case-insensitively.
Map<String, List<VpnServer>> groupByCountry(List<VpnServer> servers) {
  final grouped = <String, List<VpnServer>>{};
  for (final server in servers) {
    grouped.putIfAbsent(server.country, () => []).add(server);
  }
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return {for (final key in sortedKeys) key: grouped[key]!};
}

/// Filters a curated list (bookmarks/recents) by the active search query.
List<VpnServer> filterByQuery(List<VpnServer> servers, String query) {
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

int reachableCount(List<VpnServer> servers) =>
    servers.where((s) => s.ping != null).length;

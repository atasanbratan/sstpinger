import '../../domain/entities/vpn_server.dart';
import '../../domain/repositories/vpn_server_repository.dart';
import '../datasources/preferences_data_source.dart';
import '../datasources/vpn_remote_data_source.dart';

/// Server list + bookmarks, backed by the remote API and local preferences.
/// Holds the in-memory cache the old `VpnRepository` did. It also records the
/// subscription window returned alongside a fetch (via the shared preferences
/// data source) — `SubscriptionRepository` reads that back for display.
class VpnServerRepositoryImpl implements VpnServerRepository {
  final VpnRemoteDataSource _remote;
  final PreferencesDataSource _prefs;

  List<VpnServer> _cached = [];

  VpnServerRepositoryImpl(this._remote, this._prefs);

  @override
  List<VpnServer> get cachedServers => _cached;

  @override
  Future<List<VpnServer>> fetchServers() async {
    final username = await _prefs.getUsername();
    final deviceId = await _prefs.getOrCreateDeviceId();

    if (username.isEmpty || deviceId.isEmpty) {
      _cached = [];
      await _prefs.saveServersWithPing(_cached);
      return [];
    }

    final response = await _remote.fetchVpnServers(
      username: username,
      deviceId: deviceId,
    );
    await _prefs.saveSubscriptionInfo(
      expireTime: response.expireTime,
      lastFetch: DateTime.now(),
    );

    // The backend does not know our latency measurements, so a fetch would
    // otherwise wipe every ping value the user just measured (on launch, and on
    // every Refresh). Carry them over by endpoint.
    _cached = await _withKnownPings(response.servers);
    await _prefs.saveServersWithPing(_cached);
    return _cached;
  }

  /// Re-applies previously measured ping values to [fresh], matching on
  /// `ip:port` — the backend's `id` can change, the endpoint does not.
  Future<List<VpnServer>> _withKnownPings(List<VpnServer> fresh) async {
    final known = <String, int>{
      for (final s in [..._cached, ...await _prefs.loadServersWithPing()])
        if (s.ping != null) s.endpoint: s.ping!,
    };
    if (known.isEmpty) return fresh;
    return [
      for (final s in fresh)
        known.containsKey(s.endpoint) ? s.copyWith(ping: known[s.endpoint]) : s,
    ];
  }

  @override
  Future<List<VpnServer>> refreshAndMerge() async {
    final username = await _prefs.getUsername();
    final deviceId = await _prefs.getOrCreateDeviceId();

    final old = await _prefs.loadServersWithPing();
    final response = await _remote.fetchVpnServers(
      username: username,
      deviceId: deviceId,
    );
    await _prefs.saveSubscriptionInfo(
      expireTime: response.expireTime,
      lastFetch: DateTime.now(),
    );

    final merged = <VpnServer>[...old];
    for (final server in response.servers) {
      final exists = merged.any(
        (s) => s.ip == server.ip && s.port == server.port,
      );
      if (!exists) merged.add(server);
    }

    _cached = merged;
    await _prefs.saveServersWithPing(merged);
    return merged;
  }

  @override
  Future<List<VpnServer>> loadCached() => _prefs.loadServersWithPing();

  @override
  Future<void> saveWithPing(List<VpnServer> servers) async {
    await _prefs.saveServersWithPing(servers);
    _cached = servers;
  }

  @override
  Future<void> clearServers() async {
    _cached = [];
    await _prefs.saveServersWithPing([]);
  }

  @override
  Future<List<VpnServer>> loadBookmarks() => _prefs.getBookmarkedServers();

  @override
  Future<void> saveBookmarks(List<VpnServer> servers) =>
      _prefs.saveBookmarkedServers(servers);
}

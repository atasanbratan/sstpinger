import '../entities/vpn_server.dart';

/// Contract for obtaining and persisting the server list and bookmarks. The
/// implementation lives in `data/` — the domain only owns this interface, so
/// dependencies point inward.
abstract class VpnServerRepository {
  /// The last known server list held in memory (empty before the first load).
  List<VpnServer> get cachedServers;

  /// Fetches the server list from the backend for the stored identity and caches
  /// it. Returns an empty list if there is no username/device id yet. Throws
  /// [SubscriptionExpiredException] / [ApiException] on backend errors.
  Future<List<VpnServer>> fetchServers();

  /// Fetches the latest list and merges it with what is cached, keeping servers
  /// the backend has dropped (matched by ip:port). Used for background refresh.
  Future<List<VpnServer>> refreshAndMerge();

  /// Loads the persisted server list (with saved ping values).
  Future<List<VpnServer>> loadCached();

  /// Persists [servers] (including their ping values) and updates the in-memory
  /// cache.
  Future<void> saveWithPing(List<VpnServer> servers);

  /// Clears the server list from memory and the persisted cache.
  Future<void> clearServers();

  Future<List<VpnServer>> loadBookmarks();

  Future<void> saveBookmarks(List<VpnServer> servers);

  Future<List<VpnServer>> loadRecents();

  Future<void> saveRecents(List<VpnServer> servers);
}

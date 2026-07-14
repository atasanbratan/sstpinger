import 'dart:convert';
import 'dart:math';

import '../models/vpn_server.dart';
import '../services/preferences_service.dart';
import '../services/vpn_api_client.dart';

class VpnRepository {
  final VpnApiClient _apiClient;
  final PreferencesService _preferencesService;

  List<VpnServer> _cachedServers = [];
  List<VpnServer> get cachedServers => _cachedServers;

  DateTime? _expireTime;
  DateTime? get expireTime => _expireTime;

  DateTime? _lastFetchTime;
  DateTime? get lastFetchTime => _lastFetchTime;

  VpnRepository({
    VpnApiClient? apiClient,
    PreferencesService? preferencesService,
  }) : _apiClient = apiClient ?? VpnApiClient(),
       _preferencesService = preferencesService ?? PreferencesService();

  Future<String> getUsername() => _preferencesService.getUsername();

  Future<void> saveUsername(String username) =>
      _preferencesService.saveUsername(username);

  Future<String> getOrCreateDeviceId() =>
      _preferencesService.getOrCreateDeviceId();

  Future<void> saveServersWithPing(List<VpnServer> servers) async {
    await _preferencesService.saveServersWithPing(servers);
    _cachedServers = servers;
  }

  Future<List<VpnServer>> loadServersWithPing() async {
    return await _preferencesService.loadServersWithPing();
  }

  Future<List<VpnServer>> loadBookmarkedServers() =>
      _preferencesService.getBookmarkedServers();

  Future<void> saveBookmarkedServers(List<VpnServer> servers) =>
      _preferencesService.saveBookmarkedServers(servers);

  Future<int> getPingTimeoutMs() => _preferencesService.getPingTimeoutMs();

  Future<int> getPingBatchSize() => _preferencesService.getPingBatchSize();

  Future<void> savePingSettings({
    required int timeoutMs,
    required int batchSize,
  }) => _preferencesService.savePingSettings(
    timeoutMs: timeoutMs,
    batchSize: batchSize,
  );

  /// Clears the server list from both memory and the persisted cache.
  Future<void> clearServers() async {
    _cachedServers = [];
    await _preferencesService.saveServersWithPing([]);
  }

  /// Loads persisted subscription expiry and last-fetch time into memory so
  /// the UI can display them before the first network fetch completes.
  Future<void> loadSubscriptionInfo() async {
    _expireTime = await _preferencesService.getExpireTime();
    _lastFetchTime = await _preferencesService.getLastFetchTime();
  }

  Future<void> _recordSubscriptionInfo(DateTime? expireTime) async {
    _expireTime = expireTime ?? _expireTime;
    _lastFetchTime = DateTime.now();
    await _preferencesService.saveSubscriptionInfo(
      expireTime: expireTime,
      lastFetch: _lastFetchTime!,
    );
  }

  Future<List<VpnServer>> fetchVpnServers() async {
    final username = await getUsername();
    final deviceId = await getOrCreateDeviceId();

    if (username.isEmpty || deviceId.isEmpty) {
      _cachedServers = [];
      await saveServersWithPing(_cachedServers);
      return [];
    }

    final response = await _apiClient.fetchVpnServers(
      username: username,
      deviceId: deviceId,
    );
    await _recordSubscriptionInfo(response.expireTime);

    final servers = response.servers;

    await saveServersWithPing(servers);
    _cachedServers = servers;
    return servers;
  }

  /// Foreign variant: starts the one-time free trial and imports the resulting
  /// activation blob.
  Future<void> startFreeTrial() async {
    final deviceId = await getOrCreateDeviceId();
    final username = await _getOrCreateUsername();

    final blob = await _apiClient.startTrial(
      username: username,
      deviceId: deviceId,
    );

    await importActivationCode(blob);
  }

  /// Foreign variant: verifies a crypto payment on the backend and imports the
  /// resulting activation blob. A stable username is generated on first use and
  /// reused for renewals so the subscription stays tied to this install.
  Future<void> subscribeWithCrypto({
    required String network,
    required String txHash,
  }) async {
    final deviceId = await getOrCreateDeviceId();
    final username = await _getOrCreateUsername();

    final blob = await _apiClient.subscribe(
      username: username,
      deviceId: deviceId,
      network: network,
      txHash: txHash,
    );

    await importActivationCode(blob);
  }

  Future<String> _getOrCreateUsername() async {
    var username = await getUsername();
    if (username.isEmpty) {
      username = _generateUsername();
      await saveUsername(username);
    }
    return username;
  }

  String _generateUsername() {
    final random = Random.secure();
    final suffix = List<int>.generate(6, (_) => random.nextInt(16))
        .map((n) => n.toRadixString(16))
        .join();
    return 'sst_$suffix';
  }

  Future<void> importActivationCode(String base64) async {
    final decoded = utf8.decode(base64Decode(base64));

    final Map<String, dynamic> json = jsonDecode(decoded);

    final username = json['username'] as String;

    final servers = (json['data'] as List)
        .map((e) => VpnServer.fromJson(e))
        .toList();

    await saveUsername(username);
    await saveServersWithPing(servers);

    _cachedServers = servers;
  }

  Future<List<VpnServer>> fetchServersAndMerge() async {
    final username = await getUsername();
    final deviceId = await getOrCreateDeviceId();

    final oldServers = await loadServersWithPing();

    final response = await _apiClient.fetchVpnServers(
      username: username,
      deviceId: deviceId,
    );
    await _recordSubscriptionInfo(response.expireTime);
    final latest = response.servers;

    final merged = <VpnServer>[...oldServers];

    for (final server in latest) {
      final exists = merged.any(
        (s) => s.ip == server.ip && s.port == server.port,
      );

      if (!exists) {
        merged.add(server);
      }
    }

    _cachedServers = merged;

    await saveServersWithPing(merged);

    return merged;
  }
}

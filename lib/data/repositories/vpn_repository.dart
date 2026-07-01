import '../models/vpn_server.dart';
import '../services/preferences_service.dart';
import '../services/vpn_api_client.dart';

class VpnRepository {
  final VpnApiClient _apiClient;
  final PreferencesService _preferencesService;

  List<VpnServer> _cachedServers = [];
  List<VpnServer> get cachedServers => _cachedServers;

  VpnRepository({
    VpnApiClient? apiClient,
    PreferencesService? preferencesService,
  })  : _apiClient = apiClient ?? VpnApiClient(),
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

  Future<List<VpnServer>> fetchVpnServers() async {
    final username = await getUsername();
    final deviceId = await getOrCreateDeviceId();
    
    if (username.isEmpty || deviceId.isEmpty) {
      _cachedServers = [];
      await saveServersWithPing(_cachedServers);
      return [];
    }

    final servers = await _apiClient.fetchVpnServers(
      username: username,
      deviceId: deviceId,
    );
    await saveServersWithPing(servers);
    _cachedServers = servers;
    return servers;
  }
}

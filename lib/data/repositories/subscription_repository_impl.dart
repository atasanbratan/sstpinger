import 'dart:convert';
import 'dart:math';

import '../../domain/entities/subscription.dart';
import '../../domain/entities/vpn_server.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/preferences_data_source.dart';
import '../datasources/vpn_remote_data_source.dart';
import '../dto/vpn_server_dto.dart';

/// Identity, activation, and the subscription window. Activation blobs carry a
/// username and a server list; this decodes them and persists the username, but
/// leaves caching the servers to the caller (the use cases), which is why it
/// returns them.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final VpnRemoteDataSource _remote;
  final PreferencesDataSource _prefs;

  SubscriptionRepositoryImpl(this._remote, this._prefs);

  @override
  Future<String> getUsername() => _prefs.getUsername();

  @override
  Future<void> saveUsername(String username) => _prefs.saveUsername(username);

  @override
  Future<String> getOrCreateDeviceId() => _prefs.getOrCreateDeviceId();

  @override
  Future<Subscription> loadSubscription() async {
    return Subscription(
      expireTime: await _prefs.getExpireTime(),
      lastFetch: await _prefs.getLastFetchTime(),
    );
  }

  @override
  Future<List<VpnServer>> importActivationCode(String base64) async {
    final decoded = utf8.decode(base64Decode(base64));
    final Map<String, dynamic> json = jsonDecode(decoded);

    final username = json['username'] as String;
    final servers = VpnServerDto.listFromJson(json['data'] as List<dynamic>);

    await _prefs.saveUsername(username);
    return servers;
  }

  @override
  Future<List<VpnServer>> startFreeTrial() async {
    final deviceId = await _prefs.getOrCreateDeviceId();
    final username = await _getOrCreateUsername();

    final blob = await _remote.startTrial(username: username, deviceId: deviceId);
    return importActivationCode(blob);
  }

  @override
  Future<List<VpnServer>> subscribeWithCrypto({
    required String network,
    required String txHash,
  }) async {
    final deviceId = await _prefs.getOrCreateDeviceId();
    final username = await _getOrCreateUsername();

    final blob = await _remote.subscribe(
      username: username,
      deviceId: deviceId,
      network: network,
      txHash: txHash,
    );
    return importActivationCode(blob);
  }

  /// A stable username is generated on first use and reused for renewals so the
  /// subscription stays tied to this install.
  Future<String> _getOrCreateUsername() async {
    var username = await _prefs.getUsername();
    if (username.isEmpty) {
      username = _generateUsername();
      await _prefs.saveUsername(username);
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
}

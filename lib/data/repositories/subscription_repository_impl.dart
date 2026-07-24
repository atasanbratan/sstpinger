import 'dart:convert';
import 'dart:math';

import '../../domain/entities/auth_session.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/entities/vpn_server.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/google_auth_service.dart';
import '../datasources/preferences_data_source.dart';
import '../datasources/vpn_remote_data_source.dart';
import '../dto/vpn_server_dto.dart';

/// Identity, activation, and the subscription window. Activation blobs carry a
/// username and a server list; this decodes them and persists the username, but
/// leaves caching the servers to the caller (the use cases), which is why it
/// returns them.
///
/// Two identities coexist: a Google **session token** (the new primary auth) and
/// the legacy generated `username`+`deviceId`. When a session token is present,
/// trial/subscribe/fetch authenticate by bearer and the entitlement attaches to
/// the Google account; otherwise they use the legacy username.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final VpnRemoteDataSource _remote;
  final PreferencesDataSource _prefs;
  final GoogleAuthService _google;

  SubscriptionRepositoryImpl(this._remote, this._prefs, this._google);

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
    final token = await _prefs.getSessionToken();
    final username = token.isNotEmpty ? '' : await _getOrCreateUsername();

    final blob = await _remote.startTrial(
      username: username,
      deviceId: deviceId,
      sessionToken: token.isEmpty ? null : token,
    );
    return importActivationCode(blob);
  }

  @override
  Future<List<VpnServer>> subscribeWithCrypto({
    required String network,
    required String txHash,
  }) async {
    final deviceId = await _prefs.getOrCreateDeviceId();
    final token = await _prefs.getSessionToken();
    final username = token.isNotEmpty ? '' : await _getOrCreateUsername();

    final blob = await _remote.subscribe(
      username: username,
      deviceId: deviceId,
      network: network,
      txHash: txHash,
      sessionToken: token.isEmpty ? null : token,
    );
    return importActivationCode(blob);
  }

  @override
  bool get isGoogleSignInSupported => _google.isSupported;

  @override
  Future<bool> hasSession() async =>
      (await _prefs.getSessionToken()).isNotEmpty;

  @override
  Future<String> getAccountEmail() => _prefs.getAccountEmail();

  @override
  Future<AuthSession?> signInWithGoogle() async {
    final idToken = await _google.signInIdToken();
    if (idToken == null) return null; // cancelled

    final deviceId = await _prefs.getOrCreateDeviceId();
    final result = await _remote.authGoogle(idToken: idToken, deviceId: deviceId);
    await _prefs.saveSession(
      token: result.sessionToken,
      email: result.session.email,
    );
    return result.session;
  }

  @override
  Future<void> signOut() async {
    final token = await _prefs.getSessionToken();
    if (token.isNotEmpty) {
      await _revokeCurrentSession(token);
    }
    await _google.signOut();
    await _prefs.clearSession();
  }

  /// Best-effort revoke of *this* device's session on the backend, so signing
  /// out doesn't leave a "ghost" session occupying a slot until it's separately
  /// revoked or naturally evicted. The API has no "revoke my own session"
  /// shortcut, so this looks its row up by device id first. Never throws —
  /// local sign-out must succeed regardless of backend/network state.
  Future<void> _revokeCurrentSession(String token) async {
    try {
      final deviceId = await _prefs.getOrCreateDeviceId();
      final sessions = await _remote.listSessions(sessionToken: token);
      for (final session in sessions) {
        if (session.deviceId == deviceId) {
          await _remote.revokeSession(sessionToken: token, id: session.id);
          break;
        }
      }
    } catch (_) {
      // Ignore — sign-out proceeds locally regardless.
    }
  }

  @override
  Future<List<UserSession>> listSessions() async {
    final token = await _prefs.getSessionToken();
    if (token.isEmpty) return const [];
    return _remote.listSessions(sessionToken: token);
  }

  @override
  Future<void> revokeSession(int id) async {
    final token = await _prefs.getSessionToken();
    if (token.isEmpty) return;
    await _remote.revokeSession(sessionToken: token, id: id);
  }

  /// A stable username is generated on first use and reused for renewals so the
  /// subscription stays tied to this install (legacy, non-Google path).
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

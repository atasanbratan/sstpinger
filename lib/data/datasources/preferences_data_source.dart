import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:advertising_id/advertising_id.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/ping_mode.dart';
import '../../domain/entities/tunnel_protocol.dart';
import '../../domain/entities/vpn_server.dart';
import '../dto/vpn_server_dto.dart';

/// Local persistence via `shared_preferences`: identity (username, device id),
/// the cached server list, bookmarks, subscription window, and ping settings.
/// Thin I/O only — orchestration lives in the repositories.
class PreferencesDataSource {
  static const String _keyUsername = 'username';
  static const String _keyDeviceId = 'device_id';
  // Google Sign-In identity: the opaque bearer session token minted by the
  // backend's /api/auth/google, and the signed-in account email (display only).
  static const String _keySessionToken = 'session_token';
  static const String _keyAccountEmail = 'account_email';
  // Whether the "sign in to keep access" nudge has already been shown once
  // after a trial/subscription success, so it never nags twice.
  static const String _keyGoogleLinkPromptSeen = 'google_link_prompt_seen';
  static const String _keyExpireTime = 'subscription_expire_time';
  static const String _keyLastFetch = 'servers_last_fetch';
  static const String _keyPingTimeoutMs = 'ping_timeout_ms';
  static const String _keyPingBatchSize = 'ping_batch_size';
  static const String _keyBookmarks = 'bookmarked_servers';
  static const String _keyRecents = 'recent_servers';
  static const String _keyServersWithPing = 'servers_with_ping';
  static const String _keyReconnectRetryCount = 'reconnect_retry_count';
  static const String _keyReconnectRetryIntervalSec =
      'reconnect_retry_interval_sec';
  static const String _keyServersFlatView = 'servers_flat_view';
  static const String _keyProtocol = 'tunnel_protocol';
  static const String _keyPingMode = 'ping_mode';
  static const String _keySoftEtherDisableNatT = 'softether_disable_natt';
  static const String _keySoftEtherNatTRetryWaitSec =
      'softether_natt_retry_wait_sec';
  static const String _keyFetchServerCount = 'fetch_server_count';
  static const String _keyLastExpiryWarningDate = 'last_expiry_warning_date';
  static const String _keyProxySharingEnabled = 'proxy_sharing_enabled';
  static const String _keyProxySharingPort = 'proxy_sharing_port';
  static const String _keyUseCuratedRegion = 'use_curated_region';

  static const int defaultPingTimeoutMs = 1500;
  static const int defaultPingBatchSize = 100;

  // How many servers each fetch requests from the backend. Clamped to
  // [50, 5000]; the backend clamps identically as a backstop.
  static const int defaultFetchServerCount = 1000;
  static const int minFetchServerCount = 50;
  static const int maxFetchServerCount = 5000;

  // Reconnection defaults: on an unexpected drop, retry a few times a few
  // seconds apart. A retry count of 0 disables auto-reconnection.
  static const int defaultReconnectRetryCount = 1;
  static const int defaultReconnectRetryIntervalSec = 5;

  // SoftEther transport defaults: try NAT-T disabled (direct TCP) first, as it
  // completes on the widest range of VPN Gate relays, waiting this long before
  // falling back to the other transport.
  static const bool defaultSoftEtherDisableNatT = true;
  static const int defaultSoftEtherNatTRetryWaitSec = 15;

  static const bool defaultProxySharingEnabled = false;
  static const int defaultProxySharingPort = 1080;

  // Full list by default; the curated pool is an opt-in for whichever ISP
  // it's built for (see SettingsRepository.getUseCuratedRegion doc).
  static const bool defaultUseCuratedRegion = false;
  static const String curatedRegionPool = 'ASTU';

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? '';
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username.trim());
  }

  /// The backend session bearer token (empty when not signed in with Google).
  Future<String> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySessionToken) ?? '';
  }

  Future<void> saveSession({
    required String token,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionToken, token);
    await prefs.setString(_keyAccountEmail, email);
  }

  Future<String> getAccountEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccountEmail) ?? '';
  }

  /// Clears the Google/session identity (used on sign-out).
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionToken);
    await prefs.remove(_keyAccountEmail);
  }

  Future<bool> getGoogleLinkPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGoogleLinkPromptSeen) ?? false;
  }

  Future<void> saveGoogleLinkPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGoogleLinkPromptSeen, true);
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedId = prefs.getString(_keyDeviceId);
    if (cachedId != null && cachedId.isNotEmpty) {
      return cachedId;
    }
    await _generateOrFetchDeviceId(prefs);
    return prefs.getString(_keyDeviceId) ?? '';
  }

  Future<void> saveServersWithPing(List<VpnServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyServersWithPing,
      jsonEncode(VpnServerDto.listToJson(servers)),
    );
  }

  Future<List<VpnServer>> loadServersWithPing() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_keyServersWithPing);
    if (encoded == null || encoded.isEmpty) return [];
    return VpnServerDto.listFromJson(jsonDecode(encoded) as List<dynamic>);
  }

  Future<void> saveSubscriptionInfo({
    DateTime? expireTime,
    required DateTime lastFetch,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (expireTime != null) {
      await prefs.setString(_keyExpireTime, expireTime.toIso8601String());
    }
    await prefs.setString(_keyLastFetch, lastFetch.toIso8601String());
  }

  Future<DateTime?> getExpireTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyExpireTime);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<DateTime?> getLastFetchTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastFetch);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// The calendar date (local, midnight-truncated) the expiry-soon banner was
  /// last shown, so it fires at most once per day.
  Future<DateTime?> getLastExpiryWarningDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastExpiryWarningDate);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveLastExpiryWarningDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastExpiryWarningDate, date.toIso8601String());
  }

  Future<int> getPingTimeoutMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPingTimeoutMs) ?? defaultPingTimeoutMs;
  }

  Future<int> getPingBatchSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPingBatchSize) ?? defaultPingBatchSize;
  }

  Future<void> savePingSettings({
    required int timeoutMs,
    required int batchSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPingTimeoutMs, timeoutMs);
    await prefs.setInt(_keyPingBatchSize, batchSize);
  }

  Future<int> getReconnectRetryCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyReconnectRetryCount) ?? defaultReconnectRetryCount;
  }

  Future<int> getReconnectRetryIntervalSec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyReconnectRetryIntervalSec) ??
        defaultReconnectRetryIntervalSec;
  }

  Future<void> saveReconnectSettings({
    required int retryCount,
    required int retryIntervalSec,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReconnectRetryCount, retryCount);
    await prefs.setInt(_keyReconnectRetryIntervalSec, retryIntervalSec);
  }

  Future<int> getFetchServerCount() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_keyFetchServerCount) ?? defaultFetchServerCount;
    return v.clamp(minFetchServerCount, maxFetchServerCount);
  }

  Future<void> setFetchServerCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _keyFetchServerCount, count.clamp(minFetchServerCount, maxFetchServerCount));
  }

  Future<bool> getSoftEtherDisableNatT() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySoftEtherDisableNatT) ??
        defaultSoftEtherDisableNatT;
  }

  Future<int> getSoftEtherNatTRetryWaitSec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySoftEtherNatTRetryWaitSec) ??
        defaultSoftEtherNatTRetryWaitSec;
  }

  Future<void> saveSoftEtherNatTSettings({
    required bool disableNatT,
    required int retryWaitSec,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoftEtherDisableNatT, disableNatT);
    await prefs.setInt(_keySoftEtherNatTRetryWaitSec, retryWaitSec);
  }

  /// Whether to fetch from the curated regional pool (servers pre-verified
  /// reachable from a specific ISP) instead of the full server list.
  Future<bool> getUseCuratedRegion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUseCuratedRegion) ?? defaultUseCuratedRegion;
  }

  Future<void> saveUseCuratedRegion(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseCuratedRegion, value);
  }

  /// Servers-tab layout: true = flat list, false = grouped by country.
  Future<bool> getServersFlatView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyServersFlatView) ?? false;
  }

  Future<void> saveServersFlatView(bool flat) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyServersFlatView, flat);
  }

  /// The selected tunnel protocol, stored by its enum name.
  Future<TunnelProtocol> getProtocol() async {
    final prefs = await SharedPreferences.getInstance();
    return TunnelProtocol.fromName(prefs.getString(_keyProtocol));
  }

  Future<void> saveProtocol(TunnelProtocol protocol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProtocol, protocol.name);
  }

  /// Desktop-only: whether this device shares its VPN tunnel via a local
  /// SOCKS5 proxy, and which port it listens on.
  Future<bool> getProxySharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyProxySharingEnabled) ??
        defaultProxySharingEnabled;
  }

  Future<int> getProxySharingPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyProxySharingPort) ?? defaultProxySharingPort;
  }

  Future<void> saveProxySharingSettings({
    required bool enabled,
    required int port,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyProxySharingEnabled, enabled);
    await prefs.setInt(_keyProxySharingPort, port);
  }

  Future<PingMode> getPingMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPingMode) == 'tls' ? PingMode.tls : PingMode.tcp;
  }

  Future<void> savePingMode(PingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPingMode, mode.name);
  }

  /// Bookmarks are stored as full server records (not just endpoints) so they
  /// survive a server refetch even if the backend drops the node.
  Future<List<VpnServer>> getBookmarkedServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyBookmarks);
    if (raw == null || raw.isEmpty) return [];
    return VpnServerDto.listFromJson(jsonDecode(raw) as List<dynamic>);
  }

  Future<void> saveBookmarkedServers(List<VpnServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyBookmarks,
      jsonEncode(VpnServerDto.listToJson(servers)),
    );
  }

  /// Recently-connected servers, newest first — stored as full records (like
  /// bookmarks) so they survive a refetch even if the backend drops the node.
  Future<List<VpnServer>> getRecentServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRecents);
    if (raw == null || raw.isEmpty) return [];
    return VpnServerDto.listFromJson(jsonDecode(raw) as List<dynamic>);
  }

  Future<void> saveRecentServers(List<VpnServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyRecents,
      jsonEncode(VpnServerDto.listToJson(servers)),
    );
  }

  Future<void> _generateOrFetchDeviceId(SharedPreferences prefs) async {
    // The advertising ID only exists on Android/iOS. On desktop the plugin is
    // absent, so asking for it throws MissingPluginException — don't force a
    // known failure and catch it, just skip straight to the generated UUID.
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final String? adId = await AdvertisingId.id(true);
        if (adId != null &&
            adId.isNotEmpty &&
            adId != "00000000-0000-0000-0000-000000000000") {
          await prefs.setString(_keyDeviceId, adId);
          return;
        }
        // Otherwise fall through: the user reset or opted out of their ad ID.
      } catch (e) {
        debugPrint('Failed to get Advertising ID, using a generated id: $e');
      }
    }

    // Everywhere else — desktop, or mobile with no usable ad ID — mint a random
    // UUID v4. It is persisted below and reused on every later launch, so it is
    // just as stable an identity as the ad ID; it only differs in being
    // per-install rather than per-device. Random.secure() so the id backing
    // activation is not drawn from a predictably-seeded PRNG.
    await prefs.setString(_keyDeviceId, _randomUuidV4());
  }

  String _randomUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }
}

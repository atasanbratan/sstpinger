import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:advertising_id/advertising_id.dart';
import 'package:flutter/foundation.dart';

import '../models/vpn_server.dart';

class PreferencesService {
  static const String _keyUsername = 'username';
  static const String _keyDeviceId = 'device_id';
  static const String _keyExpireTime = 'subscription_expire_time';
  static const String _keyLastFetch = 'servers_last_fetch';
  static const String _keyPingTimeoutMs = 'ping_timeout_ms';
  static const String _keyPingBatchSize = 'ping_batch_size';
  static const String _keyBookmarks = 'bookmarked_servers';

  static const int defaultPingTimeoutMs = 1500;
  static const int defaultPingBatchSize = 25;

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername) ?? '';
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username.trim());
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedId = prefs.getString(_keyDeviceId);
    if (cachedId != null && cachedId.isNotEmpty) {
      return cachedId;
    }

    await _generateOrFetchDeviceId(prefs);
    return prefs.getString(_keyDeviceId) ?? '';
  }

  Future<void> saveServersWithPing(List<VpnServer> servers) async {
    final prefs = await SharedPreferences.getInstance();

    final encodedServers = servers.map((server) => server.toJson()).toList();

    final encodedString = jsonEncode(encodedServers);
    await prefs.setString('servers_with_ping', encodedString);
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

  /// Bookmarks are stored as full server records (not just endpoints) so they
  /// survive a server refetch even if the backend drops the node.
  Future<List<VpnServer>> getBookmarkedServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyBookmarks);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => VpnServer.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBookmarkedServers(List<VpnServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(servers.map((s) => s.toJson()).toList());
    await prefs.setString(_keyBookmarks, encoded);
  }

  Future<List<VpnServer>> loadServersWithPing() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedString = prefs.getString('servers_with_ping');

    if (encodedString == null || encodedString.isEmpty) {
      return [];
    }

    final List<dynamic> decodedList = jsonDecode(encodedString);
    return decodedList
        .map((item) => VpnServer.fromJson(item as Map<String, dynamic>))
        .toList();
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

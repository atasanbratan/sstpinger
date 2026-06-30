import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:advertising_id/advertising_id.dart';
import 'package:flutter/foundation.dart';

class PreferencesService {
  static const String _keyUsername = 'username';
  static const String _keyDeviceId = 'device_id';

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

    String id = await _generateOrFetchDeviceId(prefs);
    return id;
  }

  Future<String> _generateOrFetchDeviceId(SharedPreferences prefs) async {
    // Try to get Google Ads ID (Advertising ID)
    try {
      String? adId = await AdvertisingId.id(true);
      if (adId != null &&
          adId.isNotEmpty &&
          adId != "00000000-0000-0000-0000-000000000000") {
        await prefs.setString(_keyDeviceId, adId);
        return adId;
      }
    } catch (e) {
      debugPrint('Failed to get Advertising ID: $e');
    }

    // Fallback to random UUID v4
    final random = Random();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Set version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Set variant RFC4122

    final hexList = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .toList();
    final uuid =
        '${hexList.sublist(0, 4).join()}-${hexList.sublist(4, 6).join()}-${hexList.sublist(6, 8).join()}-${hexList.sublist(8, 10).join()}-${hexList.sublist(10, 16).join()}';

    await prefs.setString(_keyDeviceId, uuid);
    return uuid;
  }
}

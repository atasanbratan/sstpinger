import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';

/// Android-only utility for in-app APK download and installation.
///
/// Constructs the per-ABI direct-download URL from the GitHub releases page,
/// downloads the file into the app cache with progress reporting, and hands
/// it to the Android system package installer via [OpenFilex].
///
/// Every public member is a no-op / returns false on non-Android platforms so
/// the caller can use [isSupported] as a guard without `dart:io` conditionals
/// scattered around the UI layer.
class ApkInstaller {
  ApkInstaller._();

  /// True when this platform supports the in-app installer (Android only).
  static bool get isSupported => Platform.isAndroid;

  /// Base URL for GitHub release assets.
  static const String _releaseBase =
      'https://github.com/sstp-pinger/sstp_shield_releases/releases/download';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the direct-download URL for the best-matching per-ABI APK.
  ///
  /// Pattern:
  ///   {_releaseBase}/v{version}/sstp-shield-{abi}.apk
  ///
  /// Falls back to the universal APK (`sstp-shield.apk`) when the device ABI
  /// is not one of the three known splits.
  static Future<String> apkUrl({required String version}) async {
    final abi = await _primaryAbi();
    final tag = 'v$version';
    final suffix = _knownAbis.contains(abi) ? '-$abi' : '';
    final filename = 'sstp-shield$suffix.apk';
    return '$_releaseBase/$tag/$filename';
  }

  /// Downloads [url] to the app cache directory, reporting progress via
  /// [onProgress] (values 0.0 → 1.0).
  ///
  /// Pass a [CancelToken] to allow mid-download cancellation. When cancelled,
  /// the partial file is deleted before re-throwing [DioException].
  ///
  /// Returns the absolute path to the saved APK on success.
  static Future<String> download(
    String url, {
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = Directory.systemTemp; // falls back on desktop (unused there)
    final savePath = '${dir.path}${Platform.pathSeparator}${_filenameFromUrl(url)}';

    final dio = Dio();
    try {
      await dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received / total);
        },
        options: Options(
          // Follow GitHub's redirect chain (302 → CDN download).
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
    } on DioException {
      // Clean up partial file on error or cancellation.
      final partial = File(savePath);
      if (await partial.exists()) await partial.delete();
      rethrow;
    }

    return savePath;
  }

  /// Launches the Android system package installer for the APK at [filePath].
  ///
  /// Returns `true` when the install intent was accepted by the OS.
  /// Returns `false` on non-Android platforms (should not be reached if the
  /// caller checks [isSupported] first).
  static Future<bool> install(String filePath) async {
    if (!Platform.isAndroid) return false;
    final result = await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
    return result.type == ResultType.done;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// The three ABI names that have dedicated splits in the release.
  static const _knownAbis = {'arm64-v8a', 'armeabi-v7a', 'x86_64'};

  /// Returns the primary ABI of the running device, or an empty string when
  /// it cannot be determined (triggers the universal fallback).
  static Future<String> _primaryAbi() async {
    try {
      if (!Platform.isAndroid) return '';
      final info = await DeviceInfoPlugin().androidInfo;
      return info.supportedAbis.isNotEmpty ? info.supportedAbis.first : '';
    } catch (_) {
      return ''; // never crash the updater
    }
  }

  /// Extracts the filename from a URL (last path segment).
  static String _filenameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri?.pathSegments.lastOrNull ?? 'update.apk';
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../core/config/backend_config.dart';
import '../../domain/entities/app_update_info.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/entities/vpn_server.dart';
import '../../domain/failures/failures.dart';
import '../dto/user_session_dto.dart';
import '../dto/vpn_server_dto.dart';

/// Result of a successful server fetch: the server list, the subscription
/// expiry, and the app-update advertisement the backend piggybacked onto the
/// response (null when the feed is absent — never an error).
class VpnServersResponse {
  final List<VpnServer> servers;
  final DateTime? expireTime;
  final AppUpdateInfo updateInfo;

  VpnServersResponse({
    required this.servers,
    this.expireTime,
    this.updateInfo = AppUpdateInfo.none,
  });
}

/// The backend HTTP client for the Go/Vercel service (see
/// ../../../../sstp_shield_server). Speaks JSON in; JSON out for most calls and
/// opaque base64 activation blobs for trial/subscribe. Maps transport and
/// backend errors to the domain [ApiException] / [SubscriptionExpiredException].
///
/// Auth is either a Google bearer **session token** (`Authorization: Bearer …`)
/// or the legacy `username`+`deviceId` pair — the backend accepts both, so
/// activation-code users keep working.
class VpnRemoteDataSource {
  final Dio _dio;

  VpnRemoteDataSource({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: BackendConfig.baseUrl)) {
    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: true,
          responseBody: true,
          error: true,
          compact: false,
          maxWidth: 120,
        ),
      );
    }
  }

  /// This platform's identifier, sent so the backend can label the session.
  /// Null on platforms with no obvious tag (web); harmless when absent.
  String? get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    return null;
  }

  Options _authOptions(String? sessionToken) => Options(
        contentType: Headers.jsonContentType,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          if (sessionToken != null && sessionToken.isNotEmpty)
            'Authorization': 'Bearer $sessionToken',
        },
      );

  /// Exchanges a Google ID token for a backend session token and the account's
  /// current subscription window. POST /api/auth/google.
  Future<({String sessionToken, AuthSession session})> authGoogle({
    required String idToken,
    required String deviceId,
  }) async {
    try {
      final response = await _dio.post<String>(
        '/api/auth/google',
        data: {
          'idToken': idToken,
          'deviceId': deviceId,
          if (_platform != null) 'platform': _platform,
        },
        options: _authOptions(null),
      );
      final decoded = _decodeJson(response.data);
      _throwIfFailure(decoded);
      final token = decoded['sessionToken']?.toString() ?? '';
      if (token.isEmpty) {
        throw const ApiException('Sign-in failed: no session token returned.');
      }
      return (
        sessionToken: token,
        session: AuthSession(
          email: decoded['email']?.toString() ?? '',
          expireTime: _parseExpireTime(decoded['expireTime']),
        ),
      );
    } on DioException catch (e) {
      throw _apiExceptionFromDio(e);
    } on FormatException {
      throw const ApiException(
        'Received an invalid response from the server. Please try again.',
      );
    }
  }

  Future<VpnServersResponse> fetchVpnServers({
    required String username,
    required String deviceId,
    String? sessionToken,
    int? count,
    String? pool,
  }) async {
    // With a session token the backend authenticates by bearer and ignores the
    // username; the legacy path sends username+deviceId+platform in the body.
    final Map<String, dynamic> payload = {
      'deviceId': deviceId,
      if (sessionToken == null || sessionToken.isEmpty) 'username': username,
      'pool': ?pool,
      'count': ?count,
      if (_platform != null) 'platform': _platform,
    };

    try {
      final response = await _dio.post<String>(
        '/api/servers',
        data: payload,
        options: _authOptions(sessionToken).copyWith(
          connectTimeout: const Duration(seconds: 40),
        ),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          'The server returned an error (${response.statusCode}). '
          'Please try again later.',
        );
      }

      final decoded = _decodeJson(response.data);
      _throwIfFailure(decoded);

      final list = decoded['data'] as List<dynamic>? ?? [];
      return VpnServersResponse(
        servers: VpnServerDto.listFromJson(list),
        expireTime: _parseExpireTime(decoded['expireTime']),
        updateInfo: _parseUpdateInfo(decoded),
      );
    } on DioException catch (e) {
      throw _apiExceptionFromDio(e);
    } on FormatException {
      throw const ApiException(
        'Received an invalid response from the server. Please try again.',
      );
    }
  }

  /// Lists the signed-in account's registered sessions. GET /api/sessions.
  Future<List<UserSession>> listSessions({required String sessionToken}) async {
    try {
      final response = await _dio.get<String>(
        '/api/sessions',
        options: _authOptions(sessionToken),
      );
      final decoded = _decodeJson(response.data);
      _throwIfFailure(decoded);
      final list = decoded['sessions'] as List<dynamic>? ?? [];
      return UserSessionDto.listFromJson(list);
    } on DioException catch (e) {
      throw _apiExceptionFromDio(e);
    } on FormatException {
      throw const ApiException(
        'Received an invalid response from the server. Please try again.',
      );
    }
  }

  /// Revokes one of the account's own sessions. DELETE /api/sessions/{id}.
  Future<void> revokeSession({
    required String sessionToken,
    required int id,
  }) async {
    try {
      final response = await _dio.delete<String>(
        '/api/sessions/$id',
        options: _authOptions(sessionToken),
      );
      _throwIfFailure(_decodeJson(response.data));
    } on DioException catch (e) {
      throw _apiExceptionFromDio(e);
    } on FormatException {
      throw const ApiException(
        'Received an invalid response from the server. Please try again.',
      );
    }
  }

  /// Starts the one-time free trial. Attaches to the Google account when a
  /// session token is present, else to the legacy username+device. POST
  /// /api/trial → base64 activation blob.
  Future<String> startTrial({
    required String username,
    required String deviceId,
    String? sessionToken,
  }) {
    return _activationRequest('/api/trial', {
      'username': username,
      'deviceId': deviceId,
    }, sessionToken);
  }

  /// Submits a crypto payment; the backend verifies it on-chain and, on success,
  /// returns a base64 activation blob. POST /api/subscribe.
  Future<String> subscribe({
    required String username,
    required String deviceId,
    required String network,
    required String txHash,
    String? sessionToken,
  }) {
    return _activationRequest('/api/subscribe', {
      'username': username,
      'deviceId': deviceId,
      'network': network,
      'txHash': txHash,
    }, sessionToken);
  }

  /// Hits an activation endpoint (trial/subscribe) that returns an opaque base64
  /// blob on success or a JSON error object on failure.
  Future<String> _activationRequest(
    String path,
    Map<String, dynamic> body,
    String? sessionToken,
  ) async {
    try {
      final response = await _dio.post<String>(
        path,
        data: body,
        options: _authOptions(sessionToken),
      );
      final raw = (response.data ?? '').trim();

      // A JSON object means the backend rejected the request; the success path
      // returns an opaque base64 blob (no leading brace).
      if (raw.startsWith('{')) {
        _throwIfFailure(jsonDecode(raw) as Map<String, dynamic>);
      }
      if (raw.isEmpty) {
        throw const ApiException('Empty response from the server.');
      }
      return raw;
    } on DioException catch (e) {
      throw _apiExceptionFromDio(e);
    } on FormatException {
      throw const ApiException(
        'Received an invalid response from the server. Please try again.',
      );
    }
  }

  Map<String, dynamic> _decodeJson(String? body) {
    final decoded = jsonDecode(body ?? '');
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }

  /// Throws the mapped domain exception when a `{success:false}` body is seen.
  void _throwIfFailure(Map<String, dynamic> decoded) {
    if (decoded['success'] == true) return;
    if (decoded['code'] == 'SUBSCRIPTION_EXPIRED') {
      throw SubscriptionExpiredException(
        decoded['error']?.toString() ?? 'Your subscription has expired.',
      );
    }
    throw ApiException(
      decoded['error']?.toString() ??
          'The server rejected the request. Please try again.',
    );
  }

  DateTime? _parseExpireTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  /// Reads the update feed the backend piggybacks onto a fetch. Every field is
  /// nullable so a missing or malformed value yields [AppUpdateInfo.none] — the
  /// updater must never be able to break the app, so a bad feed shows nothing.
  AppUpdateInfo _parseUpdateInfo(Map<String, dynamic> decoded) {
    final latest = _asStringOrNull(decoded['latestVersion']);
    final min = _asStringOrNull(decoded['minVersion']);
    final url = _asStringOrNull(decoded['updateUrl']);
    if (latest == null && min == null && url == null) {
      return AppUpdateInfo.none;
    }
    return AppUpdateInfo(
      latestVersion: latest,
      minVersion: min,
      updateUrl: url,
    );
  }

  /// Trims a JSON value to a string, returning null when absent or whitespace-only
  /// (never an empty string — empty is not a useful version).
  static String? _asStringOrNull(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Maps a [DioException] to a readable [ApiException]. Lives here (data) rather
  /// than on the domain exception, which must stay free of `dio`.
  static ApiException _apiExceptionFromDio(DioException e) {
    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout =>
        'The connection timed out. Please check your internet and try again.',
      DioExceptionType.connectionError => _connectionErrorMessage(e),
      DioExceptionType.badCertificate =>
        'Could not establish a secure connection to the server.',
      DioExceptionType.badResponse =>
        'The server returned an error '
            '(${e.response?.statusCode ?? 'unknown'}). Please try again later.',
      DioExceptionType.cancel => 'The request was cancelled.',
      DioExceptionType.unknown => _connectionErrorMessage(e),
    };
    return ApiException(message);
  }

  static String _connectionErrorMessage(DioException e) {
    if (e.error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'Couldn\'t reach the server. Please check your connection.';
  }
}

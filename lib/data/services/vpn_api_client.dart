import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../models/vpn_server.dart';
import 'api_exception.dart';

/// Result of a successful server fetch, carrying the subscription expiry
/// reported by the backend alongside the server list.
class VpnServersResponse {
  final List<VpnServer> servers;
  final DateTime? expireTime;

  VpnServersResponse({required this.servers, this.expireTime});
}

/// Thrown when the backend reports that the user's subscription has expired
/// (error code `SUBSCRIPTION_EXPIRED`). Callers should block connecting.
class SubscriptionExpiredException implements Exception {
  final String message;

  SubscriptionExpiredException([
    this.message = 'Your subscription has expired.',
  ]);

  @override
  String toString() => message;
}

class VpnApiClient {
  final Dio _dio;
  static const String _url =
      'https://script.google.com/macros/s/AKfycbyqKggC-QqxUAoc-u_8uut3gbHoFMXUr5-N7gQlIp53Ga6juJ8g12jJFvEiDgp9-I2c/exec';

  VpnApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    // Verbose request/response logging, debug builds only.
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

  Future<VpnServersResponse> fetchVpnServers({
    required String username,
    required String deviceId,
  }) async {
    final Map<String, dynamic> payload = {
      'deviceId': deviceId,
      'username': username,
    };

    try {
      Response<String> response = await _dio.post(
        _url,
        queryParameters: payload,
        data: payload,
        options: Options(
          contentType: Headers.jsonContentType,
          followRedirects: false, // Manually handle redirect hop
          validateStatus: (status) => status! < 500,
          connectTimeout: const Duration(seconds: 8),
        ),
      );

      String? redirectUrl;

      if (response.headers['location'] != null &&
          response.headers['location']!.isNotEmpty) {
        redirectUrl = response.headers['location']!.first;
      } else if (response.data != null &&
          response.data.toString().contains('href="')) {
        final dataStr = response.data.toString();
        final regExp = RegExp(r'href="([^"]+)"');
        final match = regExp.firstMatch(dataStr);
        if (match != null) {
          redirectUrl = match.group(1)?.replaceAll('&amp;', '&');
        }
      }

      if (redirectUrl != null) {
        final finalResponse = await _dio.get<String>(redirectUrl);
        response = finalResponse;
      }

      if (response.statusCode != 200) {
        throw ApiException(
          'The server returned an error (${response.statusCode}). '
          'Please try again later.',
        );
      }

      final Map<String, dynamic> decoded = jsonDecode(response.data ?? "");

      if (decoded['success'] != true) {
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

      final list = decoded['data'] as List<dynamic>? ?? [];
      return VpnServersResponse(
        servers: list.map((item) => VpnServer.fromJson(item)).toList(),
        expireTime: _parseExpireTime(decoded['expireTime']),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(
        'Received an invalid response from the server. Please try again.',
      );
    }
  }

  /// Starts the one-time free trial for the foreign variant. Returns the same
  /// base64 activation blob the app imports.
  Future<String> startTrial({
    required String username,
    required String deviceId,
  }) {
    return _activationRequest({
      'action': 'trial',
      'username': username,
      'deviceId': deviceId,
    });
  }

  /// Submits a crypto payment for the foreign variant. The backend verifies
  /// the transaction on-chain and, on success, returns a base64 activation
  /// blob (same shape the activation-code import consumes).
  Future<String> subscribe({
    required String username,
    required String deviceId,
    required String network,
    required String txHash,
  }) {
    return _activationRequest({
      'action': 'subscribe',
      'username': username,
      'deviceId': deviceId,
      'network': network,
      'txHash': txHash,
    });
  }

  /// Hits an activation endpoint (trial/subscribe) that returns an opaque
  /// base64 blob on success or a JSON error object on failure. The error is
  /// surfaced as an [ApiException].
  Future<String> _activationRequest(Map<String, String> query) async {
    try {
      final response = await _dio.get<String>(_url, queryParameters: query);
      final body = (response.data ?? '').trim();

      // A JSON object means the backend rejected the request; the success
      // path returns an opaque base64 blob (no leading brace).
      if (body.startsWith('{')) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        if (decoded['success'] == false) {
          if (decoded['code'] == 'SUBSCRIPTION_EXPIRED') {
            throw SubscriptionExpiredException(
              decoded['error']?.toString() ?? 'Your subscription has expired.',
            );
          }
          throw ApiException(
            decoded['error']?.toString() ??
                'The request could not be completed. Please try again.',
          );
        }
      }

      if (body.isEmpty) {
        throw const ApiException('Empty response from the server.');
      }
      return body;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(
        'Received an invalid response from the server. Please try again.',
      );
    }
  }

  DateTime? _parseExpireTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }
}

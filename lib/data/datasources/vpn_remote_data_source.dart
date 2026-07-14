import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../domain/entities/vpn_server.dart';
import '../../domain/failures/failures.dart';
import '../dto/vpn_server_dto.dart';

/// Result of a successful server fetch: the server list plus the subscription
/// expiry the backend reported alongside it.
class VpnServersResponse {
  final List<VpnServer> servers;
  final DateTime? expireTime;

  VpnServersResponse({required this.servers, this.expireTime});
}

/// The backend HTTP client (Google Apps Script endpoint). Speaks JSON in, opaque
/// base64 activation blobs out; maps transport and backend errors to the domain
/// [ApiException] / [SubscriptionExpiredException].
class VpnRemoteDataSource {
  final Dio _dio;
  static const String _url =
      'https://script.google.com/macros/s/AKfycbyqKggC-QqxUAoc-u_8uut3gbHoFMXUr5-N7gQlIp53Ga6juJ8g12jJFvEiDgp9-I2c/exec';

  VpnRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio() {
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
        servers: VpnServerDto.listFromJson(list),
        expireTime: _parseExpireTime(decoded['expireTime']),
      );
    } on DioException catch (e) {
      throw _apiExceptionFromDio(e);
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

  /// Submits a crypto payment for the foreign variant. The backend verifies the
  /// transaction on-chain and, on success, returns a base64 activation blob.
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

  /// Hits an activation endpoint (trial/subscribe) that returns an opaque base64
  /// blob on success or a JSON error object on failure.
  Future<String> _activationRequest(Map<String, String> query) async {
    try {
      final response = await _dio.get<String>(_url, queryParameters: query);
      final body = (response.data ?? '').trim();

      // A JSON object means the backend rejected the request; the success path
      // returns an opaque base64 blob (no leading brace).
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
      throw _apiExceptionFromDio(e);
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

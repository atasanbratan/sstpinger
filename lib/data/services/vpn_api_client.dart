import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/vpn_server.dart';

class VpnApiClient {
  final Dio _dio;
  static const String _url =
      'https://script.google.com/macros/s/AKfycbyqKggC-QqxUAoc-u_8uut3gbHoFMXUr5-N7gQlIp53Ga6juJ8g12jJFvEiDgp9-I2c/exec';

  VpnApiClient({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<VpnServer>> fetchVpnServers({
    required String username,
    required String deviceId,
  }) async {
    final Map<String, dynamic> payload = {
      'deviceId': deviceId,
      'username': username,
    };

    Response<String> response = await _dio.post(
      _url,
      queryParameters: payload,
      data: payload,
      options: Options(
        contentType: Headers.jsonContentType,
        followRedirects: false, // Manually handle redirect hop
        validateStatus: (status) => status! < 500,
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

    if (response.statusCode == 200) {
      final Map<String, dynamic> decoded = jsonDecode(response.data ?? "");
      if (decoded['success'] == true) {
        final list = decoded['data'] as List<dynamic>? ?? [];
        return list.map((item) => VpnServer.fromJson(item)).toList();
      } else {
        throw Exception(decoded['error'] ?? 'API success flag is false');
      }
    } else {
      throw Exception('API responded with status: ${response.statusCode}');
    }
  }
}

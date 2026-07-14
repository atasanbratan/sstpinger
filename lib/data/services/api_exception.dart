import 'dart:io';

import 'package:dio/dio.dart';

/// A network/API failure with a message that is safe to show to the user.
///
/// Raw [DioException]s stringify to long, unreadable diagnostics; this wraps
/// them (and other API failures) in a short, human-friendly sentence.
class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  /// Maps a [DioException] to a readable message based on its failure type.
  factory ApiException.fromDio(DioException e) {
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

  @override
  String toString() => message;
}

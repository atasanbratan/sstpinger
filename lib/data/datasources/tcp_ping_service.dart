import 'dart:io';

import '../../domain/entities/vpn_server.dart';
import '../../domain/repositories/ping_service.dart';

/// Measures reachability by timing a raw TCP connect to the server's `ip:port`.
class TcpPingService implements PingService {
  const TcpPingService();

  @override
  Future<int?> ping(VpnServer server, {required int timeoutMs}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        server.ip,
        server.port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      stopwatch.stop();
      await socket.close();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }
}

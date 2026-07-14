import 'dart:io';

import '../models/vpn_server.dart';

/// Measures reachability of a server by timing a raw TCP connect to its
/// `ip:port`. Returns the round-trip in milliseconds, or `null` if the server
/// could not be reached within [timeoutMs] (i.e. it is effectively dead).
///
/// Shared by the VPN client (sorting by latency) and the admin console
/// (finding non-pingable servers to purge).
class PingService {
  const PingService();

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

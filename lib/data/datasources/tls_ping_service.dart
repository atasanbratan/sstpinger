import 'package:sstp_vpn_plugin/sstp_vpn_plugin.dart' show tlsHandshakePing;

import '../../domain/entities/vpn_server.dart';
import '../../domain/repositories/ping_service.dart';

/// Measures reachability with a **TLS handshake** rather than a bare TCP connect.
/// Routes through the bundled uTLS relay when present (matching the SSTP client's
/// real connect path on fingerprint-filtering networks), otherwise a plain
/// [SecureSocket] handshake. A server whose TLS is blocked or broken reads as
/// unreachable instead of falsely "fast".
class TlsPingService implements PingService {
  const TlsPingService();

  @override
  Future<int?> ping(VpnServer server, {required int timeoutMs}) =>
      tlsHandshakePing(
        server.ip,
        server.port,
        timeout: Duration(milliseconds: timeoutMs),
      );
}

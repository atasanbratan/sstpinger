import '../entities/vpn_server.dart';

/// Contract for measuring a single server's reachability. The implementation
/// times a raw TCP connect. Kept as a domain port so ping-orchestrating use
/// cases don't depend on `dart:io`.
abstract class PingService {
  /// Returns the round-trip in milliseconds, or null if [server] could not be
  /// reached within [timeoutMs] (i.e. it is effectively dead).
  Future<int?> ping(VpnServer server, {required int timeoutMs});
}

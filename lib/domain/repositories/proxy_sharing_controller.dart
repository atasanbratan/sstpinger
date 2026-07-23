/// Contract for sharing this device's active VPN tunnel with other LAN
/// devices via a local proxy listener. Once the tunnel is up, the OS default
/// route already carries this process's own outbound sockets over it, so
/// relaying a LAN peer's TCP connection is plain local I/O — no packet-level
/// routing needed. Implemented for desktop (Linux/Windows) and Android; no
/// iOS implementation, since VpnService's Android equivalent doesn't exist
/// there in the same form — callers only construct/use this where supported.
abstract class ProxySharingController {
  /// Number of concurrently relayed client connections, for a live indicator.
  Stream<int> get connectedClients;

  bool get isRunning;

  Future<void> start(int port);

  Future<void> stop();

  void dispose();
}

import '../repositories/tunnel_controller.dart';

/// Tears the tunnel down. The resulting `disconnected` report arrives on
/// `TunnelController.updates`.
class DisconnectTunnel {
  final TunnelController _controller;

  const DisconnectTunnel(this._controller);

  Future<void> call() => _controller.disconnect();
}

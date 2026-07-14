import '../entities/tunnel_config.dart';
import '../repositories/tunnel_controller.dart';

/// Brings the tunnel up: first obtains platform consent (the Android VPN dialog;
/// a no-op on desktop), then connects. Progress and the eventual result arrive
/// on `TunnelController.updates`.
class ConnectTunnel {
  final TunnelController _controller;

  const ConnectTunnel(this._controller);

  Future<void> call(TunnelConfig config) async {
    await _controller.requestPermission();
    await _controller.connect(config);
  }
}

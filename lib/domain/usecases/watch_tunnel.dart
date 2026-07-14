import '../entities/tunnel_status.dart';
import '../entities/tunnel_update.dart';
import '../repositories/tunnel_controller.dart';

/// Exposes the tunnel's report stream and its last known status, so the
/// connection bloc can subscribe once and recover a pre-existing connection
/// (e.g. an Android tunnel still running in a foreground service).
class WatchTunnel {
  final TunnelController _controller;

  const WatchTunnel(this._controller);

  Stream<TunnelUpdate> get updates => _controller.updates;

  Future<TunnelStatus> lastStatus() => _controller.lastStatus();
}

import '../../domain/entities/tunnel_config.dart';
import '../../domain/entities/tunnel_status.dart';
import '../../domain/entities/tunnel_traffic.dart';

/// Low-level, callback-based tunnel contract — the shape the underlying plugins
/// naturally expose. `TunnelControllerImpl` adapts this into the domain's
/// stream-based `TunnelController`. Two implementations exist (mobile via
/// `sstp_flutter`, desktop via `sstp_vpn_plugin`).
abstract class TunnelDataSource {
  /// Status of a tunnel that may have outlived the UI (Android foreground
  /// service). Desktop dies with the process, so there is nothing to recover.
  Future<TunnelStatus> lastStatus();

  /// Registers the connection callbacks. Call once, before [connect].
  /// [onConnected] fires repeatedly while up, carrying live traffic/duration.
  void onResult({
    required void Function(TunnelTraffic? traffic, Duration duration) onConnected,
    required void Function() onConnecting,
    required void Function() onDisconnected,
    required void Function(String message) onError,
  });

  Future<void> requestPermission();

  Future<void> connect(TunnelConfig config);

  Future<void> disconnect();

  void dispose();
}

import '../entities/tunnel_config.dart';
import '../entities/tunnel_status.dart';
import '../entities/tunnel_update.dart';

/// Contract for the VPN tunnel, abstracted away from whichever plugin provides
/// it. Two implementations exist because no single plugin spans the app's
/// targets: `sstp_flutter` on Android/iOS, our `sstp_vpn_plugin` on
/// Linux/Windows. The platform is chosen at construction, in `data/`, so no
/// `Platform.isX` check leaks into the domain or presentation layers.
abstract class TunnelController {
  /// A stream of tunnel reports (status changes, live traffic/duration while
  /// connected, and failures). Listen before calling [connect].
  Stream<TunnelUpdate> get updates;

  /// The status of a tunnel that may have outlived the UI (Android keeps the VPN
  /// running in a foreground service). Desktop tunnels die with the process, so
  /// there is never anything to recover.
  Future<TunnelStatus> lastStatus();

  /// Obtains whatever consent the platform demands before a tunnel may exist
  /// (Android's system VPN dialog). A no-op where privilege is granted outside
  /// the app, as on desktop.
  Future<void> requestPermission();

  Future<void> connect(TunnelConfig config);

  Future<void> disconnect();

  /// Releases listeners and timers. The tunnel itself is not torn down.
  void dispose();
}

import 'dart:io';

import '../models/tunnel_traffic.dart';
import 'desktop_sstp_tunnel_service.dart';
import 'mobile_sstp_tunnel_service.dart';

/// Connection states, as strings, because the UI already keys off these exact
/// values (see `SSTPConnectionStatusKeys`) and `sstp_flutter` reports them as
/// strings too.
class VpnTunnelStatus {
  static const String connected = 'Connected';
  static const String connecting = 'Connecting';
  static const String disconnected = 'Disconnected';
  static const String disconnecting = 'Disconnecting';
}

/// Everything needed to bring a tunnel up. Plain data — no plugin types, so the
/// VM can build one without knowing which platform it is on.
class VpnTunnelConfig {
  const VpnTunnelConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.label,
  });

  final String host;
  final int port;
  final String username;
  final String password;

  /// Human-readable server name, e.g. for the Android notification.
  final String label;
}

/// The tunnel, abstracted away from whichever plugin provides it.
///
/// Two implementations exist because no single plugin spans the platforms this
/// app targets:
///
/// | Platform      | Implementation             | Mechanism             |
/// |---------------|----------------------------|-----------------------|
/// | Android / iOS | [MobileSstpTunnelService]  | `sstp_flutter`        |
/// | Linux / Windows | [DesktopSstpTunnelService] | `sstp_vpn_plugin`   |
///
/// The VM depends on this interface only, so no `Platform.isX` check leaks into
/// the view models or the widgets.
abstract class VpnTunnelService {
  /// The tunnel implementation for the platform this build is running on.
  ///
  /// Throws [UnsupportedError] rather than silently degrading: an app that
  /// pretends to have a VPN and does not is worse than one that refuses to
  /// start. (macOS is absent on purpose — `sstp_vpn_plugin` excludes it because
  /// its utun backend has never been proven against a live server.)
  factory VpnTunnelService.forPlatform() {
    if (Platform.isAndroid || Platform.isIOS) {
      return MobileSstpTunnelService();
    }
    if (Platform.isLinux || Platform.isWindows) {
      return DesktopSstpTunnelService();
    }
    throw UnsupportedError(
      'No SSTP tunnel implementation for ${Platform.operatingSystem}.',
    );
  }

  /// The status of a tunnel that may have outlived the UI (Android keeps the
  /// VPN running in a foreground service). Desktop tunnels die with the process,
  /// so there is never anything to recover.
  Future<String> lastConnectionStatus();

  /// Registers the connection callbacks. Call once, before [connect].
  ///
  /// [onConnected] fires repeatedly while the tunnel is up — that is how the UI
  /// gets its live traffic and duration.
  void onResult({
    required void Function(TunnelTraffic? traffic, Duration duration) onConnected,
    required void Function() onConnecting,
    required void Function() onDisconnected,
    required void Function(String message) onError,
  });

  /// Obtains whatever consent the platform demands before a tunnel may exist
  /// (Android's system VPN dialog). A no-op where privilege is granted outside
  /// the app, as on desktop.
  Future<void> requestPermission();

  Future<void> connect(VpnTunnelConfig config);

  Future<void> disconnect();

  /// Releases listeners and timers. The tunnel itself is not torn down.
  void dispose();
}

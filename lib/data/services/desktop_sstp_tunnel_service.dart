import 'dart:async';
import 'dart:io';

import 'package:sstp_vpn_plugin/sstp_vpn_plugin.dart';

import '../models/tunnel_traffic.dart';
import 'vpn_tunnel_service.dart';

/// Linux / Windows tunnel, via our own `sstp_vpn_plugin`.
///
/// The only place `sstp_vpn_plugin` is imported. Two things differ from mobile
/// and are handled here rather than being pushed onto the VM:
///
/// * **No byte counters.** The plugin reports status, not throughput, so
///   [TunnelTraffic] comes back null and the UI shows 0. Faking numbers would be
///   worse than showing none.
/// * **No status ticks.** The plugin emits a status once, on change; it does not
///   pulse while connected. Mobile's `onConnected` fires repeatedly and that is
///   what drives the on-screen timer, so a ticker here supplies the same beat.
class DesktopSstpTunnelService implements VpnTunnelService {
  final SstpVpnClient _client = SstpVpnClient();

  StreamSubscription<VpnStatus>? _statusSub;
  Timer? _ticker;
  DateTime? _connectedAt;

  void Function(TunnelTraffic? traffic, Duration duration)? _onConnected;
  void Function()? _onConnecting;
  void Function()? _onDisconnected;
  void Function(String message)? _onError;

  /// Nothing survives the process on desktop: the tun device is owned by this
  /// process's file descriptor, and the routes are torn down with it. So there
  /// is never a previous connection to recover.
  @override
  Future<String> lastConnectionStatus() async => VpnTunnelStatus.disconnected;

  @override
  void onResult({
    required void Function(TunnelTraffic? traffic, Duration duration) onConnected,
    required void Function() onConnecting,
    required void Function() onDisconnected,
    required void Function(String message) onError,
  }) {
    _onConnected = onConnected;
    _onConnecting = onConnecting;
    _onDisconnected = onDisconnected;
    _onError = onError;

    _statusSub?.cancel();
    _statusSub = _client.status.listen((status) {
      switch (status) {
        case VpnStatus.connecting:
          _onConnecting?.call();
        case VpnStatus.connected:
          _connectedAt = DateTime.now();
          _startTicker();
        case VpnStatus.disconnected:
        case VpnStatus.disconnecting:
          _stopTicker();
          _onDisconnected?.call();
        case VpnStatus.missingPrivilege:
        case VpnStatus.handshakeFailed:
        case VpnStatus.tunnelSetupFailed:
          _stopTicker();
          _onError?.call(_messageFor(status));
      }
    });
  }

  /// The plugin's errors are the same on both desktop platforms, but the remedy
  /// is not — CAP_NET_ADMIN on Linux, Administrator on Windows — so the privilege
  /// message has to name the right one.
  String _messageFor(VpnStatus status) => switch (status) {
    VpnStatus.missingPrivilege => Platform.isWindows
        ? 'This app must run as Administrator to create a VPN adapter.'
        : 'This app needs CAP_NET_ADMIN to create a VPN interface. '
              'Run tool/setup_privilege.sh once — do not use sudo.',
    VpnStatus.handshakeFailed =>
      'Could not connect to the server. Check the address and credentials, '
          'or choose another server.',
    VpnStatus.tunnelSetupFailed =>
      'The tunnel could not be set up. Another VPN may be active.',
    _ => 'Connection failed. Please choose another server.',
  };

  /// Desktop privilege is arranged outside the app (a file capability on Linux,
  /// the elevation manifest on Windows), so there is no in-app consent step. If
  /// privilege is missing, `connect()` says so as `missingPrivilege`.
  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> connect(VpnTunnelConfig config) async {
    // Rethrown as-is: the VM already reports connect() failures, and the status
    // stream will have carried the typed cause.
    await _client.connect(
      host: config.host,
      port: config.port,
      username: config.username,
      password: config.password,
      verifyCert: false, // VPN Gate servers are self-signed.
      routeMode: RouteMode.full,
    );
  }

  @override
  Future<void> disconnect() => _client.disconnect();

  void _startTicker() {
    _ticker?.cancel();
    // Fire immediately so the UI flips to "connected" without waiting a second.
    _emitConnected();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitConnected(),
    );
  }

  void _emitConnected() {
    final since = _connectedAt;
    if (since == null) return;
    // Null traffic, not zeroed traffic: the plugin counts no bytes, and the UI
    // renders null as 0 anyway.
    _onConnected?.call(null, DateTime.now().difference(since));
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _connectedAt = null;
  }

  @override
  void dispose() {
    _stopTicker();
    _statusSub?.cancel();
    _client.dispose();
  }
}

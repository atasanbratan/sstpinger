import 'dart:async';
import 'dart:io';

import 'package:sstp_vpn_plugin/sstp_vpn_plugin.dart';

import '../../domain/entities/tunnel_config.dart';
import '../../domain/entities/tunnel_protocol.dart';
import '../../domain/entities/tunnel_status.dart';
import '../../domain/entities/tunnel_traffic.dart';
import 'tunnel_data_source.dart';

/// Linux / Windows tunnel, via our own `sstp_vpn_plugin`. The only place
/// `sstp_vpn_plugin` is imported. It carries **two backends** — SSTP
/// (`SstpVpnClient`, our pure-Dart stack) and SoftEther (`SoftEtherClient`,
/// driving the official vpnclient/vpncmd) — chosen per connect by
/// [TunnelConfig.protocol]. SoftEther is Linux-only for now.
///
/// Two things differ from mobile and are handled here rather than pushed up:
///
/// * **No byte counters.** Neither backend reports throughput, so
///   [TunnelTraffic] comes back null and the UI shows 0.
/// * **No status ticks.** They emit a status once, on change; a ticker here
///   supplies the per-second beat mobile's repeated `onConnected` gives.
class DesktopTunnelDataSource implements TunnelDataSource {
  final SstpVpnClient _sstp = SstpVpnClient();
  SoftEtherConnection? _softether;
  bool _softEtherActive = false;

  StreamSubscription<VpnStatus>? _sstpSub;
  StreamSubscription<SoftEtherStatus>? _softetherSub;
  Timer? _ticker;
  DateTime? _connectedAt;

  void Function(TunnelTraffic? traffic, Duration duration)? _onConnected;
  void Function()? _onConnecting;
  void Function()? _onDisconnected;
  void Function(String message)? _onError;

  @override
  Future<TunnelStatus> lastStatus() async => TunnelStatus.disconnected;

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

    _sstpSub?.cancel();
    _sstpSub = _sstp.status.listen((status) {
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
          _onError?.call(_sstpMessageFor(status));
      }
    });
  }

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> connect(TunnelConfig config) async {
    if (config.protocol == TunnelProtocol.softEther) {
      return _connectSoftEther(config);
    }
    _softEtherActive = false;
    try {
      await _sstp.connect(
        host: config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        verifyCert: false, // VPN Gate servers are self-signed.
        routeMode: RouteMode.full,
      );
    } on SstpVpnException catch (e) {
      // A cancel mid-handshake completes connect() with an error; not worth
      // surfacing — the status stream already reported `disconnected`.
      if (e.status == VpnStatus.disconnected) return;
      rethrow;
    }
  }

  Future<void> _connectSoftEther(TunnelConfig config) async {
    _softEtherActive = true;
    final binDir = _softetherBinDir;
    final client = _softether ??= SoftEtherConnection.forPlatform(
      binDir: binDir,
      // Linux only; Windows drives the client directly (already elevated).
      helperPath: '$binDir${Platform.pathSeparator}softether-helper',
    );
    _bindSoftEther(client);
    try {
      await client.connect(
        host: config.host,
        port: config.port,
        username: config.username,
        password: config.password,
      );
    } on SoftEtherException catch (e) {
      if (e.status == SoftEtherStatus.disconnected) return;
      rethrow;
    }
  }

  void _bindSoftEther(SoftEtherConnection client) {
    _softetherSub?.cancel();
    _softetherSub = client.status.listen((status) {
      switch (status) {
        case SoftEtherStatus.connecting:
          _onConnecting?.call();
        case SoftEtherStatus.connected:
          _connectedAt = DateTime.now();
          _startTicker();
        case SoftEtherStatus.disconnected:
        case SoftEtherStatus.disconnecting:
          _stopTicker();
          _onDisconnected?.call();
        case SoftEtherStatus.connectFailed:
        case SoftEtherStatus.missingPrivilege:
        case SoftEtherStatus.error:
          _stopTicker();
          _onError?.call(_softEtherMessageFor(status));
      }
    });
  }

  /// Where the bundled SoftEther binaries (vpnclient/vpncmd/hamcore.se2) live.
  /// `SOFTETHER_DIR` overrides; otherwise a `softether/` folder beside the
  /// executable (where the release bundle ships them).
  String get _softetherBinDir {
    final env = Platform.environment['SOFTETHER_DIR'];
    if (env != null && env.isNotEmpty) return env;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir${Platform.pathSeparator}softether';
  }

  String _sstpMessageFor(VpnStatus status) => switch (status) {
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

  String _softEtherMessageFor(SoftEtherStatus status) => switch (status) {
    SoftEtherStatus.missingPrivilege =>
      'SoftEther needs root to create its adapter. Launch the app elevated.',
    SoftEtherStatus.connectFailed =>
      'Could not establish the SoftEther session. Try another server.',
    _ => 'SoftEther connection failed. Please try another server.',
  };

  @override
  Future<void> disconnect() => _softEtherActive
      ? (_softether?.disconnect() ?? Future.value())
      : _sstp.disconnect();

  void _startTicker() {
    _ticker?.cancel();
    _emitConnected(); // flip to "connected" immediately, no 1s wait
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emitConnected());
  }

  void _emitConnected() {
    final since = _connectedAt;
    if (since == null) return;
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
    _sstpSub?.cancel();
    _softetherSub?.cancel();
    _sstp.dispose();
    _softether?.dispose();
  }
}

import 'dart:async';
import 'dart:io';

import '../../domain/entities/tunnel_config.dart';
import '../../domain/entities/tunnel_status.dart';
import '../../domain/entities/tunnel_update.dart';
import '../../domain/repositories/tunnel_controller.dart';
import '../datasources/desktop_tunnel_data_source.dart';
import '../datasources/mobile_tunnel_data_source.dart';
import '../datasources/tunnel_data_source.dart';

/// Adapts a callback-based [TunnelDataSource] into the domain's stream-based
/// [TunnelController]: the data source's `onResult` callbacks become
/// [TunnelUpdate]s on a broadcast stream.
class TunnelControllerImpl implements TunnelController {
  final TunnelDataSource _dataSource;
  final StreamController<TunnelUpdate> _updates =
      StreamController<TunnelUpdate>.broadcast();

  // `sstp_flutter` (mobile) fires `onDisconnectedResult` unconditionally and,
  // for a failed connection, `onError` immediately after it — synchronously,
  // in the same native callback — for what is really one event. Pushed as two
  // separate updates, ConnectionBloc's drop handler ran twice per real
  // failure: the plain "disconnected" scheduled a retry, then the "error"
  // right behind it saw the just-incremented attempt count and gave up,
  // *without* cancelling that first retry's timer. The dangling timer fired
  // later, restarting the cycle with the attempt counter reset — an infinite
  // "reconnecting 1/1" loop. Coalescing into a single push (a plain
  // disconnect only actually goes out if no error follows in the same
  // synchronous turn) fixes it at the source, for every data source.
  bool _disconnectPending = false;

  TunnelControllerImpl(this._dataSource) {
    _dataSource.onResult(
      onConnected: (traffic, duration) => _push(
        TunnelUpdate(
          status: TunnelStatus.connected,
          traffic: traffic,
          duration: duration,
        ),
      ),
      onConnecting: () => _push(const TunnelUpdate(status: TunnelStatus.connecting)),
      onDisconnected: () {
        _disconnectPending = true;
        scheduleMicrotask(() {
          if (_disconnectPending) {
            _disconnectPending = false;
            _push(const TunnelUpdate(status: TunnelStatus.disconnected));
          }
        });
      },
      onError: (message) {
        _disconnectPending = false;
        _push(
          TunnelUpdate(status: TunnelStatus.disconnected, errorMessage: message),
        );
      },
    );
  }

  /// The tunnel implementation for the platform this build runs on. Throws
  /// [UnsupportedError] rather than silently degrading. (macOS is absent on
  /// purpose — `sstp_vpn_plugin` excludes its unproven utun backend.)
  factory TunnelControllerImpl.forPlatform() {
    if (Platform.isAndroid || Platform.isIOS) {
      return TunnelControllerImpl(MobileTunnelDataSource());
    }
    if (Platform.isLinux || Platform.isWindows) {
      return TunnelControllerImpl(DesktopTunnelDataSource());
    }
    throw UnsupportedError(
      'No SSTP tunnel implementation for ${Platform.operatingSystem}.',
    );
  }

  void _push(TunnelUpdate update) {
    if (!_updates.isClosed) _updates.add(update);
  }

  @override
  Stream<TunnelUpdate> get updates => _updates.stream;

  @override
  Future<TunnelStatus> lastStatus() => _dataSource.lastStatus();

  @override
  Future<void> requestPermission() => _dataSource.requestPermission();

  @override
  Future<void> connect(TunnelConfig config) => _dataSource.connect(config);

  @override
  Future<void> disconnect() => _dataSource.disconnect();

  @override
  void dispose() {
    _dataSource.dispose();
    _updates.close();
  }
}

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/tunnel_config.dart';
import '../../../domain/entities/tunnel_status.dart';
import '../../../domain/entities/tunnel_traffic.dart';
import '../../../domain/entities/tunnel_update.dart';
import '../../../domain/repositories/proxy_sharing_controller.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../domain/usecases/connect_tunnel.dart';
import '../../../domain/usecases/disconnect_tunnel.dart';
import '../../../domain/usecases/watch_tunnel.dart';

part 'connection_event.dart';
part 'connection_state.dart';

/// Owns the tunnel lifecycle: subscribes to the controller's report stream and
/// maps it to [VpnConnectionState]. The config to connect with is built by the
/// screen from [VpnBloc]'s selected server / custom config, so this bloc stays
/// independent of the server list.
///
/// It also drives **auto-reconnection**: when a connected (or connecting) tunnel
/// drops without the user asking, it retries the last config up to
/// [SettingsRepository.getReconnectRetryCount] times,
/// [SettingsRepository.getReconnectRetryIntervalSeconds] apart. A count of 0
/// disables it. A user-initiated disconnect never reconnects.
class ConnectionBloc extends Bloc<ConnectionEvent, VpnConnectionState> {
  final ConnectTunnel _connect;
  final DisconnectTunnel _disconnect;
  final WatchTunnel _watch;
  final SettingsRepository _settings;

  /// Desktop and Android; null on platforms with no proxy-sharing
  /// implementation (iOS).
  final ProxySharingController? _proxySharing;

  StreamSubscription<TunnelUpdate>? _subscription;
  int _errorSeq = 0;

  // Reconnection bookkeeping.
  TunnelConfig? _lastConfig; // what to retry with
  bool _intentionalDisconnect = false; // user asked to disconnect → don't retry
  int _reconnectAttempt = 0; // attempts since the last successful connect
  Timer? _reconnectTimer;
  int _retryCount = 1; // cached from settings, refreshed on manual connect
  int _retryIntervalSec = 5;

  ConnectionBloc({
    required ConnectTunnel connect,
    required DisconnectTunnel disconnect,
    required WatchTunnel watch,
    required SettingsRepository settings,
    ProxySharingController? proxySharing,
  }) : _connect = connect,
       _disconnect = disconnect,
       _watch = watch,
       _settings = settings,
       _proxySharing = proxySharing,
       super(const VpnConnectionState.initial()) {
    on<ConnectionStarted>(_onStarted);
    on<ConnectRequested>(_onConnect);
    on<DisconnectRequested>(_onDisconnect);
    on<_TunnelReported>(_onReported);
    add(const ConnectionStarted());
  }

  Future<void> _onStarted(
    ConnectionStarted event,
    Emitter<VpnConnectionState> emit,
  ) async {
    _subscription = _watch.updates.listen((u) => add(_TunnelReported(u)));
    _retryCount = await _settings.getReconnectRetryCount();
    _retryIntervalSec = await _settings.getReconnectRetryIntervalSeconds();
    final last = await _watch.lastStatus();
    emit(state.copyWith(status: last));
  }

  Future<void> _onConnect(
    ConnectRequested event,
    Emitter<VpnConnectionState> emit,
  ) async {
    // A fresh, user-initiated connect resets the retry state and picks up any
    // reconnection settings the user just changed. An automatic retry keeps its
    // running attempt count.
    if (!event.isReconnect) {
      _intentionalDisconnect = false;
      _reconnectAttempt = 0;
      _cancelReconnect();
      _retryCount = await _settings.getReconnectRetryCount();
      _retryIntervalSec = await _settings.getReconnectRetryIntervalSeconds();
    }
    _lastConfig = event.config;

    // Optimistic, matching the old VM; the stream then drives the rest.
    emit(state.copyWith(status: TunnelStatus.connecting, label: event.config.label));
    try {
      await _connect(event.config);
    } catch (e) {
      // A synchronous failure is a drop too — let the retry policy handle it.
      _handleDrop('Error starting VPN: $e', emit);
    }
  }

  Future<void> _onDisconnect(
    DisconnectRequested event,
    Emitter<VpnConnectionState> emit,
  ) async {
    // Mark intentional first so the resulting `disconnected` report — and any
    // pending retry timer — don't trigger a reconnection.
    _intentionalDisconnect = true;
    _reconnectAttempt = 0;
    _cancelReconnect();
    try {
      await _disconnect();
    } catch (e) {
      emit(state.copyWith(error: _error('Error disconnecting: $e')));
    }
  }

  void _onReported(_TunnelReported event, Emitter<VpnConnectionState> emit) {
    final update = event.update;
    final wasActive = state.status.isActive; // connected or connecting

    if (update.isError) {
      _handleDrop(update.errorMessage!, emit);
      return;
    }
    switch (update.status) {
      case TunnelStatus.connected:
        _reconnectAttempt = 0;
        _cancelReconnect();
        emit(
          state.copyWith(
            status: TunnelStatus.connected,
            traffic: update.traffic,
            duration: update.duration,
          ),
        );
        unawaited(_startProxySharingIfEnabled());
      case TunnelStatus.connecting:
        emit(state.copyWith(status: TunnelStatus.connecting));
      case TunnelStatus.disconnected:
      case TunnelStatus.disconnecting:
        // A `disconnected` while we were up and didn't ask for it is a drop.
        if (update.status == TunnelStatus.disconnected &&
            wasActive &&
            !_intentionalDisconnect) {
          _handleDrop('Connection lost.', emit);
        } else {
          emit(
            state.copyWith(
              status: update.status,
              clearTraffic: true,
              duration: Duration.zero,
              label: update.status == TunnelStatus.disconnected ? '' : null,
            ),
          );
          unawaited(_proxySharing?.stop());
        }
    }
  }

  /// Starts the local SOCKS5 listener if the user has proxy sharing enabled
  /// in settings. No-op on platforms without [_proxySharing] (mobile).
  Future<void> _startProxySharingIfEnabled() async {
    final proxy = _proxySharing;
    if (proxy == null) return;
    final enabled = await _settings.getProxySharingEnabled();
    if (!enabled) return;
    final port = await _settings.getProxySharingPort();
    await proxy.start(port);
  }

  /// Reacts to a lost connection: either schedule a retry (staying in a
  /// "connecting" state) or, if retries are off or exhausted, settle on
  /// disconnected with an explanatory error.
  void _handleDrop(String reason, Emitter<VpnConnectionState> emit) {
    unawaited(_proxySharing?.stop());
    final canRetry = !_intentionalDisconnect &&
        _lastConfig != null &&
        _retryCount > 0 &&
        _reconnectAttempt < _retryCount;

    if (canRetry) {
      _reconnectAttempt++;
      emit(
        state.copyWith(
          status: TunnelStatus.connecting,
          clearTraffic: true,
          duration: Duration.zero,
          error: _error('Connection lost — reconnecting '
              '($_reconnectAttempt/$_retryCount)…'),
        ),
      );
      _cancelReconnect();
      _reconnectTimer = Timer(Duration(seconds: _retryIntervalSec), () {
        if (_intentionalDisconnect || _lastConfig == null) return;
        add(ConnectRequested(_lastConfig!, isReconnect: true));
      });
      return;
    }

    final exhausted = !_intentionalDisconnect &&
        _retryCount > 0 &&
        _reconnectAttempt >= _retryCount;
    _reconnectAttempt = 0;
    // Defensive: settling here means we are done retrying, so no earlier
    // scheduled retry timer should be left alive to fire later and restart
    // the cycle with a freshly-reset attempt count.
    _cancelReconnect();
    emit(
      state.copyWith(
        status: TunnelStatus.disconnected,
        clearTraffic: true,
        duration: Duration.zero,
        label: '',
        error: _error(
          exhausted ? 'Reconnection failed after $_retryCount attempts.' : reason,
        ),
      ),
    );
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  ConnectionError _error(String message) => ConnectionError(++_errorSeq, message);

  @override
  Future<void> close() {
    _cancelReconnect();
    _subscription?.cancel();
    unawaited(_proxySharing?.stop());
    return super.close();
  }
}

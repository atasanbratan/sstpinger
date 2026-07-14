import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/tunnel_config.dart';
import '../../../domain/entities/tunnel_status.dart';
import '../../../domain/entities/tunnel_traffic.dart';
import '../../../domain/entities/tunnel_update.dart';
import '../../../domain/usecases/connect_tunnel.dart';
import '../../../domain/usecases/disconnect_tunnel.dart';
import '../../../domain/usecases/watch_tunnel.dart';

part 'connection_event.dart';
part 'connection_state.dart';

/// Owns the tunnel lifecycle: subscribes to the controller's report stream and
/// maps it to [VpnConnectionState]. The config to connect with is built by the
/// screen from [VpnBloc]'s selected server / custom config, so this bloc stays
/// independent of the server list.
class ConnectionBloc extends Bloc<ConnectionEvent, VpnConnectionState> {
  final ConnectTunnel _connect;
  final DisconnectTunnel _disconnect;
  final WatchTunnel _watch;

  StreamSubscription<TunnelUpdate>? _subscription;
  int _errorSeq = 0;

  ConnectionBloc({
    required ConnectTunnel connect,
    required DisconnectTunnel disconnect,
    required WatchTunnel watch,
  }) : _connect = connect,
       _disconnect = disconnect,
       _watch = watch,
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
    final last = await _watch.lastStatus();
    emit(state.copyWith(status: last));
  }

  Future<void> _onConnect(
    ConnectRequested event,
    Emitter<VpnConnectionState> emit,
  ) async {
    // Optimistic, matching the old VM; the stream then drives the rest.
    emit(state.copyWith(status: TunnelStatus.connecting));
    try {
      await _connect(event.config);
    } catch (e) {
      emit(
        state.copyWith(
          status: TunnelStatus.disconnected,
          clearTraffic: true,
          duration: Duration.zero,
          error: _error('Error starting VPN: $e'),
        ),
      );
    }
  }

  Future<void> _onDisconnect(
    DisconnectRequested event,
    Emitter<VpnConnectionState> emit,
  ) async {
    try {
      await _disconnect();
    } catch (e) {
      emit(state.copyWith(error: _error('Error disconnecting: $e')));
    }
  }

  void _onReported(_TunnelReported event, Emitter<VpnConnectionState> emit) {
    final update = event.update;
    if (update.isError) {
      emit(
        state.copyWith(
          status: TunnelStatus.disconnected,
          clearTraffic: true,
          duration: Duration.zero,
          error: _error(update.errorMessage!),
        ),
      );
      return;
    }
    switch (update.status) {
      case TunnelStatus.connected:
        emit(
          state.copyWith(
            status: TunnelStatus.connected,
            traffic: update.traffic,
            duration: update.duration,
          ),
        );
      case TunnelStatus.connecting:
        emit(state.copyWith(status: TunnelStatus.connecting));
      case TunnelStatus.disconnected:
      case TunnelStatus.disconnecting:
        emit(
          state.copyWith(
            status: update.status,
            clearTraffic: true,
            duration: Duration.zero,
          ),
        );
    }
  }

  ConnectionError _error(String message) => ConnectionError(++_errorSeq, message);

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

part of 'connection_bloc.dart';

sealed class ConnectionEvent extends Equatable {
  const ConnectionEvent();

  @override
  List<Object?> get props => [];
}

/// Subscribe to the tunnel's report stream and recover any pre-existing status.
class ConnectionStarted extends ConnectionEvent {
  const ConnectionStarted();
}

/// Bring the tunnel up with a fully-built config (the screen validates and
/// assembles it from the selected server / custom config in [VpnBloc]).
///
/// [isReconnect] marks an automatic retry after a drop, so the bloc doesn't
/// reset the attempt counter or re-read settings — user-initiated connects leave
/// it false.
class ConnectRequested extends ConnectionEvent {
  final TunnelConfig config;
  final bool isReconnect;
  const ConnectRequested(this.config, {this.isReconnect = false});

  @override
  List<Object?> get props => [config, isReconnect];
}

/// Tear the tunnel down.
class DisconnectRequested extends ConnectionEvent {
  const DisconnectRequested();
}

/// Internal: a report arrived on the tunnel's stream.
class _TunnelReported extends ConnectionEvent {
  final TunnelUpdate update;
  const _TunnelReported(this.update);

  @override
  List<Object?> get props => [update];
}

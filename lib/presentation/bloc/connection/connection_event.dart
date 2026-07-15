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
class ConnectRequested extends ConnectionEvent {
  final TunnelConfig config;
  const ConnectRequested(this.config);

  @override
  List<Object?> get props => [config];
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

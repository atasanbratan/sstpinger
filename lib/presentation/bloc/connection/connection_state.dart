part of 'connection_bloc.dart';

/// A one-shot connection error for the screen to surface as a SnackBar. Carries
/// an incrementing [id] so two identical messages still register as a change
/// (Equatable compares only the id).
class ConnectionError extends Equatable {
  final int id;
  final String message;
  const ConnectionError(this.id, this.message);

  @override
  List<Object?> get props => [id];
}

class VpnConnectionState extends Equatable {
  final TunnelStatus status;
  final TunnelTraffic? traffic;
  final Duration duration;
  final ConnectionError? error;

  const VpnConnectionState({
    required this.status,
    this.traffic,
    this.duration = Duration.zero,
    this.error,
  });

  const VpnConnectionState.initial() : this(status: TunnelStatus.disconnected);

  /// True while a tunnel is up or coming up (the connect button becomes a
  /// disconnect button; pinging is blocked).
  bool get isConnected => status.isActive;

  VpnConnectionState copyWith({
    TunnelStatus? status,
    TunnelTraffic? traffic,
    bool clearTraffic = false,
    Duration? duration,
    ConnectionError? error,
  }) {
    return VpnConnectionState(
      status: status ?? this.status,
      traffic: clearTraffic ? null : (traffic ?? this.traffic),
      duration: duration ?? this.duration,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, traffic, duration, error];
}

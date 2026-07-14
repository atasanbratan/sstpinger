import 'package:equatable/equatable.dart';

import 'tunnel_status.dart';
import 'tunnel_traffic.dart';

/// One report from the live tunnel. The `TunnelController` publishes a stream of
/// these; the connection bloc maps them to its state.
///
/// A [status] of [TunnelStatus.connected] arrives repeatedly while the tunnel is
/// up, each time carrying fresh [traffic] and [duration] — that is what drives
/// the on-screen counters. [errorMessage] is set only on a failure report (with
/// status back to [TunnelStatus.disconnected]) and carries a
/// platform-appropriate, user-facing reason.
class TunnelUpdate extends Equatable {
  const TunnelUpdate({
    required this.status,
    this.traffic,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  final TunnelStatus status;
  final TunnelTraffic? traffic;
  final Duration duration;
  final String? errorMessage;

  bool get isError => errorMessage != null;

  @override
  List<Object?> get props => [status, traffic, duration, errorMessage];
}

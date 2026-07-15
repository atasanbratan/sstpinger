import 'package:equatable/equatable.dart';

import 'vpn_server.dart';

/// Incremental progress of a ping sweep. Emitted once per probed server so the
/// UI can show a live counter and the results as they arrive.
class PingProgress extends Equatable {
  const PingProgress({
    required this.done,
    required this.total,
    required this.servers,
  });

  /// Number of servers probed so far.
  final int done;

  /// Total servers in the sweep.
  final int total;

  /// The sweep's servers, in their original order, with ping values filled in
  /// for those probed so far.
  final List<VpnServer> servers;

  @override
  List<Object?> get props => [done, total, servers];
}

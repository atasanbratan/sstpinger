import 'dart:async';

import '../entities/ping_progress.dart';
import '../entities/vpn_server.dart';
import '../repositories/ping_service.dart';

/// Probes a list of servers for latency, [batchSize] at a time, emitting
/// [PingProgress] after **each** server completes so the UI counter advances
/// smoothly. The caller decides what to do with the results (sort, persist) once
/// the stream closes.
class PingServers {
  final PingService _pingService;

  const PingServers(this._pingService);

  /// Pings [servers] with up to [batchSize] concurrent probes, each capped at
  /// [timeoutMs]. Results fill into the emitted list in the input order.
  Stream<PingProgress> call(
    List<VpnServer> servers, {
    required int timeoutMs,
    required int batchSize,
  }) {
    final controller = StreamController<PingProgress>();
    final results = List<VpnServer>.from(servers);
    final total = results.length;
    var done = 0;

    Future<void> probe(int j) async {
      final ping = await _pingService.ping(results[j], timeoutMs: timeoutMs);
      if (ping != null) results[j] = results[j].copyWith(ping: ping);
      done++;
      if (!controller.isClosed) {
        controller.add(
          PingProgress(
            done: done,
            total: total,
            servers: List<VpnServer>.from(results),
          ),
        );
      }
    }

    () async {
      for (var i = 0; i < total; i += batchSize) {
        final end = (i + batchSize).clamp(0, total);
        await Future.wait([for (var j = i; j < end; j++) probe(j)]);
      }
      await controller.close();
    }();

    return controller.stream;
  }
}

import 'dart:async';

import '../entities/ping_mode.dart';
import '../entities/ping_progress.dart';
import '../entities/vpn_server.dart';
import '../repositories/ping_service.dart';

/// Probes a list of servers for latency, [batchSize] at a time, emitting
/// [PingProgress] as servers complete so the UI counter advances smoothly. The
/// caller decides what to do with the results (sort, persist) once the stream
/// closes.
class PingServers {
  final PingService _tcpPing;
  final PingService _tlsPing;

  const PingServers(this._tcpPing, this._tlsPing);

  /// Progress emissions are throttled to this cadence: with hundreds/thousands
  /// of servers, emitting on every single probe completion drove a full-state
  /// Bloc emit (and a full server-list rebuild) per server, which is what made
  /// a "ping all" sweep visibly hammer the UI thread. Emitting at most this
  /// often keeps the counter smooth while capping rebuilds to a fixed rate
  /// regardless of how many servers are in the sweep.
  static const _throttle = Duration(milliseconds: 120);

  /// Pings [servers] with up to [batchSize] concurrent probes, each capped at
  /// [timeoutMs]. [mode] chooses a fast TCP connect or an accurate TLS
  /// handshake. Results fill into the emitted list in the input order.
  Stream<PingProgress> call(
    List<VpnServer> servers, {
    required int timeoutMs,
    required int batchSize,
    PingMode mode = PingMode.tcp,
  }) {
    final pingService = mode == PingMode.tls ? _tlsPing : _tcpPing;
    final controller = StreamController<PingProgress>();
    final results = List<VpnServer>.from(servers);
    final total = results.length;
    var done = 0;
    DateTime? lastEmit;

    void emitProgress({bool force = false}) {
      if (controller.isClosed) return;
      final now = DateTime.now();
      if (!force &&
          lastEmit != null &&
          now.difference(lastEmit!) < _throttle) {
        return;
      }
      lastEmit = now;
      controller.add(
        PingProgress(
          done: done,
          total: total,
          servers: List<VpnServer>.from(results),
        ),
      );
    }

    Future<void> probe(int j) async {
      final ping = await pingService.ping(results[j], timeoutMs: timeoutMs);
      // Apply the result whatever it is. A null (unreachable) must CLEAR any
      // latency from an earlier sweep — otherwise re-pinging after the route
      // changed would leave the old numbers on screen, which is not what was
      // measured. Hence `withPing`, not `copyWith`.
      results[j] = results[j].withPing(ping);
      done++;
      emitProgress();
    }

    () async {
      for (var i = 0; i < total; i += batchSize) {
        final end = (i + batchSize).clamp(0, total);
        await Future.wait([for (var j = i; j < end; j++) probe(j)]);
      }
      // Always land the final, complete result even if it lands inside the
      // throttle window.
      emitProgress(force: true);
      await controller.close();
    }();

    return controller.stream;
  }
}

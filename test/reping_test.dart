import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sstp_shield/domain/entities/vpn_server.dart';
import 'package:sstp_shield/domain/usecases/ping_servers.dart';

import 'support/mocks.dart';

/// A second sweep must report what it actually measured — including "no longer
/// reachable". The reported bug: ping once with a working route, ping again with
/// a broken one, and the stale times from the first sweep stayed on screen.
void main() {
  setUpAll(registerFallbacks);

  late MockPingService ping;
  late PingServers pingServers;

  setUp(() {
    ping = MockPingService();
    pingServers = PingServers(ping);
  });

  Future<List<VpnServer>> sweep(List<VpnServer> servers) async {
    final progress =
        await pingServers(servers, timeoutMs: 500, batchSize: 10).last;
    return progress.servers;
  }

  test('a re-ping clears the latency of a server that went unreachable', () async {
    final a = server(id: 1, ip: '1.1.1.1', country: 'A');
    final b = server(id: 2, ip: '2.2.2.2', country: 'B');

    // Sweep 1: both reachable (e.g. another VPN was up).
    when(() => ping.ping(a, timeoutMs: any(named: 'timeoutMs')))
        .thenAnswer((_) async => 40);
    when(() => ping.ping(b, timeoutMs: any(named: 'timeoutMs')))
        .thenAnswer((_) async => 90);

    final first = await sweep([a, b]);
    expect(first.map((s) => s.ping), [40, 90]);

    // Sweep 2: the route is gone — nothing answers.
    when(() => ping.ping(any(), timeoutMs: any(named: 'timeoutMs')))
        .thenAnswer((_) async => null);

    final second = await sweep(first);
    expect(
      second.map((s) => s.ping),
      [null, null],
      reason: 'a failed probe must clear the stale value, not keep it',
    );
  });

  test('a re-ping overwrites an old latency with the new one', () async {
    final a = server(id: 1, ip: '1.1.1.1', country: 'A', ping: 400);

    when(() => ping.ping(any(), timeoutMs: any(named: 'timeoutMs')))
        .thenAnswer((_) async => 25);

    final result = await sweep([a]);
    expect(result.single.ping, 25);
  });
}

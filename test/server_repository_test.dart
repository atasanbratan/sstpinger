import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sstp_shield/data/datasources/preferences_data_source.dart';
import 'package:sstp_shield/data/datasources/vpn_remote_data_source.dart';
import 'package:sstp_shield/data/repositories/vpn_server_repository_impl.dart';
import 'package:sstp_shield/domain/entities/vpn_server.dart';

import 'support/mocks.dart';

class MockPrefs extends Mock implements PreferencesDataSource {}

class MockRemote extends Mock implements VpnRemoteDataSource {}

void main() {
  late MockPrefs prefs;
  late MockRemote remote;
  late VpnServerRepositoryImpl repo;

  setUpAll(registerFallbacks);

  setUp(() {
    prefs = MockPrefs();
    remote = MockRemote();
    repo = VpnServerRepositoryImpl(remote, prefs);

    when(() => prefs.getUsername()).thenAnswer((_) async => 'user');
    when(() => prefs.getOrCreateDeviceId()).thenAnswer((_) async => 'device');
    when(() => prefs.getFetchServerCount()).thenAnswer((_) async => 1000);
    when(() => prefs.saveServersWithPing(any())).thenAnswer((_) async {});
    when(
      () => prefs.saveSubscriptionInfo(
        expireTime: any(named: 'expireTime'),
        lastFetch: any(named: 'lastFetch'),
      ),
    ).thenAnswer((_) async {});
  });

  test('a fetch keeps ping values already measured for the same endpoint', () async {
    // The user pinged these before; the backend knows nothing about latency.
    final pinged = [
      server(id: 1, ip: '1.1.1.1', port: 443, country: 'A', ping: 42),
      server(id: 2, ip: '2.2.2.2', port: 443, country: 'B', ping: 130),
    ];
    when(() => prefs.loadServersWithPing()).thenAnswer((_) async => pinged);

    // The same two endpoints come back from the backend with no ping values
    // (and a changed id, which is why matching is by ip:port, not id).
    when(
      () => remote.fetchVpnServers(
        username: any(named: 'username'),
        deviceId: any(named: 'deviceId'),
        count: any(named: 'count'),
      ),
    ).thenAnswer(
      (_) async => VpnServersResponse(
        servers: [
          server(id: 99, ip: '1.1.1.1', port: 443, country: 'A'),
          server(id: 98, ip: '2.2.2.2', port: 443, country: 'B'),
          server(id: 97, ip: '3.3.3.3', port: 443, country: 'C'), // new node
        ],
      ),
    );

    final fetched = await repo.fetchServers();

    final byEndpoint = {for (final s in fetched) s.endpoint: s.ping};
    expect(byEndpoint['1.1.1.1:443'], 42, reason: 'ping must survive the fetch');
    expect(byEndpoint['2.2.2.2:443'], 130, reason: 'ping must survive the fetch');
    expect(byEndpoint['3.3.3.3:443'], isNull, reason: 'a new node has no ping yet');

    // And the values are what get persisted, so they survive a restart too.
    final saved = verify(() => prefs.saveServersWithPing(captureAny()))
        .captured
        .last as List<VpnServer>;
    expect(saved.firstWhere((s) => s.endpoint == '1.1.1.1:443').ping, 42);
  });
}

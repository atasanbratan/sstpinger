import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sstp_shield/domain/entities/tunnel_protocol.dart';
import 'package:sstp_shield/data/datasources/tcp_ping_service.dart';
import 'package:sstp_shield/domain/entities/subscription.dart';
import 'package:sstp_shield/domain/usecases/fetch_servers.dart';
import 'package:sstp_shield/domain/usecases/import_activation.dart';
import 'package:sstp_shield/domain/usecases/load_cached_servers.dart';
import 'package:sstp_shield/domain/usecases/ping_servers.dart';
import 'package:sstp_shield/domain/usecases/refresh_servers.dart';
import 'package:sstp_shield/domain/usecases/start_free_trial.dart';
import 'package:sstp_shield/domain/usecases/subscribe_with_crypto.dart';
import 'package:sstp_shield/presentation/bloc/vpn/vpn_bloc.dart';

import 'support/mocks.dart';

/// Repro: ping the list with the REAL TcpPingService against a real listening
/// socket, and check the ping values actually land in state (and get persisted).
void main() {
  setUpAll(registerFallbacks);

  test('pinging updates ping values in state and persists them', () async {
    // A real, reachable endpoint.
    final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => listener.close());

    final reachable = server(
      id: 1,
      ip: listener.address.address,
      port: listener.port,
      country: 'Reachable',
    );
    // Port 1 is refused -> unreachable.
    final dead = server(id: 2, ip: '127.0.0.1', port: 1, country: 'Dead');

    final serverRepo = MockVpnServerRepository();
    final subs = MockSubscriptionRepository();
    final settings = MockSettingsRepository();

    when(() => subs.getUsername()).thenAnswer((_) async => 'user');
    when(() => subs.getOrCreateDeviceId()).thenAnswer((_) async => 'device');
    when(() => subs.loadSubscription())
        .thenAnswer((_) async => const Subscription());
    when(() => settings.getPingTimeoutMs()).thenAnswer((_) async => 1500);
    when(() => settings.getPingBatchSize()).thenAnswer((_) async => 25);
    when(() => settings.getReconnectRetryCount()).thenAnswer((_) async => 3);
    when(() => settings.getReconnectRetryIntervalSeconds())
        .thenAnswer((_) async => 5);
    when(() => settings.getServersFlatView()).thenAnswer((_) async => false);
    when(() => settings.getProtocol())
        .thenAnswer((_) async => TunnelProtocol.sstp);
    when(() => serverRepo.loadBookmarks()).thenAnswer((_) async => []);
    when(() => serverRepo.loadRecents()).thenAnswer((_) async => []);
    when(() => serverRepo.loadCached()).thenAnswer((_) async => []);
    when(() => serverRepo.fetchServers())
        .thenAnswer((_) async => [reachable, dead]);
    when(() => serverRepo.saveWithPing(any())).thenAnswer((_) async {});
    when(() => serverRepo.cachedServers).thenReturn([]);

    final bloc = VpnBloc(
      fetchServers: FetchServers(serverRepo),
      refreshServers: RefreshServers(serverRepo),
      loadCached: LoadCachedServers(serverRepo),
      pingServers: const PingServers(TcpPingService()), // the REAL one
      importActivation: ImportActivation(subs, serverRepo),
      startFreeTrial: StartFreeTrial(subs, serverRepo),
      subscribeWithCrypto: SubscribeWithCrypto(subs, serverRepo),
      serverRepository: serverRepo,
      subscriptionRepository: subs,
      settingsRepository: settings,
    );
    addTearDown(bloc.close);

    bloc.add(const VpnStarted());
    await bloc.stream.firstWhere((s) => s.initialized);
    expect(bloc.state.servers.length, 2, reason: 'servers loaded');

    bloc.add(const PingRequested(isConnected: false));
    await bloc.stream.firstWhere((s) => !s.isPinging && s.servers.length == 2);

    final pings = {
      for (final s in bloc.state.servers) s.country: s.ping,
    };
    // ignore: avoid_print
    print('RESULT pings -> $pings');

    expect(
      pings['Reachable'],
      isNotNull,
      reason: 'a reachable server must get a ping value',
    );
    expect(pings['Dead'], isNull, reason: 'a refused server stays null');
    verify(() => serverRepo.saveWithPing(any())).called(greaterThan(0));
  });
}

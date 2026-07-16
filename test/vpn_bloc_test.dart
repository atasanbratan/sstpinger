import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sstp_shield/domain/entities/subscription.dart';
import 'package:sstp_shield/domain/entities/tunnel_protocol.dart';
import 'package:sstp_shield/domain/failures/failures.dart';
import 'package:sstp_shield/domain/usecases/fetch_servers.dart';
import 'package:sstp_shield/domain/usecases/import_activation.dart';
import 'package:sstp_shield/domain/usecases/load_cached_servers.dart';
import 'package:sstp_shield/domain/usecases/ping_servers.dart';
import 'package:sstp_shield/domain/usecases/refresh_servers.dart';
import 'package:sstp_shield/domain/usecases/start_free_trial.dart';
import 'package:sstp_shield/domain/usecases/subscribe_with_crypto.dart';
import 'package:sstp_shield/presentation/bloc/vpn/vpn_bloc.dart';

import 'support/mocks.dart';

void main() {
  late MockVpnServerRepository serverRepo;
  late MockSubscriptionRepository subs;
  late MockSettingsRepository settings;
  late MockPingService ping;

  setUpAll(registerFallbacks);

  setUp(() {
    serverRepo = MockVpnServerRepository();
    subs = MockSubscriptionRepository();
    settings = MockSettingsRepository();
    ping = MockPingService();

    // Defaults good enough for most tests; individual tests override.
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
    when(() => serverRepo.fetchServers()).thenAnswer((_) async => []);
    when(() => serverRepo.clearServers()).thenAnswer((_) async {});
    when(() => serverRepo.saveBookmarks(any())).thenAnswer((_) async {});
    when(() => serverRepo.saveRecents(any())).thenAnswer((_) async {});
    when(() => serverRepo.saveWithPing(any())).thenAnswer((_) async {});
    when(() => serverRepo.cachedServers).thenReturn([]);
    when(() => settings.saveProtocol(any())).thenAnswer((_) async {});
  });

  VpnBloc build() => VpnBloc(
    fetchServers: FetchServers(serverRepo),
    refreshServers: RefreshServers(serverRepo),
    loadCached: LoadCachedServers(serverRepo),
    pingServers: PingServers(ping),
    importActivation: ImportActivation(subs, serverRepo),
    startFreeTrial: StartFreeTrial(subs, serverRepo),
    subscribeWithCrypto: SubscribeWithCrypto(subs, serverRepo),
    serverRepository: serverRepo,
    subscriptionRepository: subs,
    settingsRepository: settings,
  );

  group('VpnStarted', () {
    final a = server(id: 1, ip: '1.1.1.1');
    final b = server(id: 2, ip: '2.2.2.2');

    blocTest<VpnBloc, VpnState>(
      'loads and fetches servers, selects the first, and initializes',
      setUp: () =>
          when(() => serverRepo.fetchServers()).thenAnswer((_) async => [a, b]),
      build: build,
      act: (bloc) => bloc.add(const VpnStarted()),
      verify: (bloc) {
        expect(bloc.state.initialized, isTrue);
        expect(bloc.state.servers, [a, b]);
        expect(bloc.state.selectedServer, a);
        expect(bloc.state.username, 'user');
      },
    );

    blocTest<VpnBloc, VpnState>(
      'a subscription-expired fetch clears servers and flags the gate',
      setUp: () => when(() => serverRepo.fetchServers())
          .thenThrow(const SubscriptionExpiredException('gone')),
      build: build,
      act: (bloc) => bloc.add(const VpnStarted()),
      verify: (bloc) {
        expect(bloc.state.isSubscriptionExpired, isTrue);
        expect(bloc.state.servers, isEmpty);
        expect(bloc.state.needsOnboarding, isTrue);
        verify(() => serverRepo.clearServers()).called(1);
      },
    );
  });

  group('PingRequested', () {
    final slow = server(id: 1, ip: '1.1.1.1');
    final fast = server(id: 2, ip: '2.2.2.2');

    blocTest<VpnBloc, VpnState>(
      'pings and sorts servers fastest-first, then persists',
      setUp: () {
        when(() => serverRepo.fetchServers())
            .thenAnswer((_) async => [slow, fast]);
        when(() => ping.ping(slow, timeoutMs: any(named: 'timeoutMs')))
            .thenAnswer((_) async => 120);
        when(() => ping.ping(fast, timeoutMs: any(named: 'timeoutMs')))
            .thenAnswer((_) async => 30);
      },
      build: build,
      act: (bloc) async {
        bloc.add(const VpnStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PingRequested(isConnected: false));
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.isPinging, isFalse);
        expect(bloc.state.servers.map((s) => s.id).toList(), [2, 1]);
        expect(bloc.state.servers.first.ping, 30);
        verify(() => serverRepo.saveWithPing(any())).called(greaterThan(0));
      },
    );

    blocTest<VpnBloc, VpnState>(
      'is blocked while connected, with a message and no ping calls',
      setUp: () => when(() => serverRepo.fetchServers())
          .thenAnswer((_) async => [slow, fast]),
      build: build,
      act: (bloc) async {
        bloc.add(const VpnStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const PingRequested(isConnected: true));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.message, isNotNull);
        expect(bloc.state.isPinging, isFalse);
        verifyNever(() => ping.ping(any(), timeoutMs: any(named: 'timeoutMs')));
      },
    );
  });

  group('bookmarks', () {
    final a = server(id: 1);

    blocTest<VpnBloc, VpnState>(
      'toggling a bookmark adds it and persists',
      build: build,
      act: (bloc) => bloc.add(BookmarkToggled(a)),
      verify: (bloc) {
        expect(bloc.state.bookmarkedServers, [a]);
        verify(() => serverRepo.saveBookmarks([a])).called(1);
      },
    );
  });

  group('protocol', () {
    blocTest<VpnBloc, VpnState>(
      'selecting an available protocol persists it',
      build: build,
      act: (bloc) => bloc.add(const ProtocolChanged(TunnelProtocol.sstp)),
      verify: (_) =>
          verify(() => settings.saveProtocol(TunnelProtocol.sstp)).called(1),
    );

    // SoftEther availability is platform-dependent (Linux desktop). Tests and CI
    // run on Linux, so it is available there and selecting it persists; the
    // "ignore unavailable" guard is exercised implicitly on platforms where it
    // is not.
    blocTest<VpnBloc, VpnState>(
      'selecting SoftEther persists it where the platform supports it',
      build: build,
      act: (bloc) => bloc.add(const ProtocolChanged(TunnelProtocol.softEther)),
      verify: (bloc) {
        if (TunnelProtocol.softEther.available) {
          expect(bloc.state.protocol, TunnelProtocol.softEther);
          verify(() => settings.saveProtocol(TunnelProtocol.softEther)).called(1);
        } else {
          expect(bloc.state.protocol, TunnelProtocol.sstp);
          verifyNever(() => settings.saveProtocol(TunnelProtocol.softEther));
        }
      },
    );
  });

  group('recents', () {
    final a = server(id: 1, ip: '1.1.1.1');
    final b = server(id: 2, ip: '2.2.2.2');

    blocTest<VpnBloc, VpnState>(
      'records connected servers newest-first, de-duplicated, and persists',
      build: build,
      act: (bloc) => bloc
        ..add(ServerConnected(a))
        ..add(ServerConnected(b))
        ..add(ServerConnected(a)), // reconnecting to a moves it back to front
      verify: (bloc) {
        expect(
          bloc.state.recentServers.map((s) => s.endpoint),
          [a.endpoint, b.endpoint], // a deduped and promoted to front
        );
        verify(() => serverRepo.saveRecents(any())).called(3);
      },
    );

    blocTest<VpnBloc, VpnState>(
      'caps the recents list at 20',
      build: build,
      act: (bloc) {
        for (var i = 0; i < 25; i++) {
          bloc.add(ServerConnected(server(id: i, ip: '10.0.0.$i')));
        }
      },
      verify: (bloc) => expect(bloc.state.recentServers.length, 20),
    );
  });

  group('activation', () {
    final a = server(id: 1);

    blocTest<VpnBloc, VpnState>(
      'a valid code unlocks servers and reports success',
      setUp: () {
        when(() => subs.importActivationCode('code'))
            .thenAnswer((_) async => [a]);
        when(() => subs.getUsername()).thenAnswer((_) async => 'unlocked');
        when(() => serverRepo.cachedServers).thenReturn([a]);
        when(() => ping.ping(any(), timeoutMs: any(named: 'timeoutMs')))
            .thenAnswer((_) async => 10);
      },
      build: build,
      act: (bloc) => bloc.add(const ActivationCodeSubmitted('code')),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.username, 'unlocked');
        expect(bloc.state.isSubscriptionExpired, isFalse);
        verify(() => serverRepo.saveWithPing([a])).called(greaterThan(0));
      },
    );

    blocTest<VpnBloc, VpnState>(
      'an invalid code surfaces a message and no unlock',
      setUp: () => when(() => subs.importActivationCode('bad'))
          .thenThrow(const FormatException('bad base64')),
      build: build,
      act: (bloc) => bloc.add(const ActivationCodeSubmitted('bad')),
      verify: (bloc) {
        expect(bloc.state.message, isNotNull);
        expect(bloc.state.actionResult?.success, isFalse);
      },
    );
  });
}

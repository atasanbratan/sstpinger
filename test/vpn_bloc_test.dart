import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sstp_shield/domain/entities/app_update_info.dart';
import 'package:sstp_shield/domain/entities/auth_session.dart';
import 'package:sstp_shield/domain/entities/ping_mode.dart';
import 'package:sstp_shield/domain/entities/subscription.dart';
import 'package:sstp_shield/domain/entities/tunnel_protocol.dart';
import 'package:sstp_shield/domain/entities/user_session.dart';
import 'package:sstp_shield/domain/failures/failures.dart';
import 'package:sstp_shield/domain/usecases/fetch_servers.dart';
import 'package:sstp_shield/domain/usecases/import_activation.dart';
import 'package:sstp_shield/domain/usecases/load_cached_servers.dart';
import 'package:sstp_shield/domain/usecases/ping_servers.dart';
import 'package:sstp_shield/domain/usecases/refresh_servers.dart';
import 'package:sstp_shield/domain/usecases/sign_in_with_google.dart';
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
    when(() => subs.hasSession()).thenAnswer((_) async => false);
    when(() => subs.getAccountEmail()).thenAnswer((_) async => '');
    when(() => subs.isGoogleSignInSupported).thenReturn(false);
    when(() => settings.getPingTimeoutMs()).thenAnswer((_) async => 1500);
    when(() => settings.getPingBatchSize()).thenAnswer((_) async => 25);
    when(() => settings.getReconnectRetryCount()).thenAnswer((_) async => 3);
    when(() => settings.getReconnectRetryIntervalSeconds())
        .thenAnswer((_) async => 5);
    when(() => settings.getFetchServerCount()).thenAnswer((_) async => 1000);
    when(() => settings.getPingMode()).thenAnswer((_) async => PingMode.tcp);
    when(() => settings.getSoftEtherDisableNatT())
        .thenAnswer((_) async => true);
    when(() => settings.getSoftEtherNatTRetryWaitSeconds())
        .thenAnswer((_) async => 15);
    when(() => settings.getServersFlatView()).thenAnswer((_) async => false);
    when(() => settings.getProtocol())
        .thenAnswer((_) async => TunnelProtocol.sstp);
    when(() => settings.getProxySharingEnabled())
        .thenAnswer((_) async => false);
    when(() => settings.getProxySharingPort()).thenAnswer((_) async => 1080);
    when(() => settings.saveProxySharingSettings(
          enabled: any(named: 'enabled'),
          port: any(named: 'port'),
        )).thenAnswer((_) async {});
    when(() => settings.getLastExpiryWarningDate())
        .thenAnswer((_) async => null);
    when(() => settings.saveLastExpiryWarningDate(any()))
        .thenAnswer((_) async {});
    when(() => settings.getUseCuratedRegion()).thenAnswer((_) async => false);
    when(() => settings.saveUseCuratedRegion(any()))
        .thenAnswer((_) async {});
    when(() => serverRepo.loadBookmarks()).thenAnswer((_) async => []);
    when(() => serverRepo.loadRecents()).thenAnswer((_) async => []);
    when(() => serverRepo.loadCached()).thenAnswer((_) async => []);
    when(() => serverRepo.fetchServers()).thenAnswer((_) async => []);
    when(() => serverRepo.clearServers()).thenAnswer((_) async {});
    when(() => serverRepo.saveBookmarks(any())).thenAnswer((_) async {});
    when(() => serverRepo.saveRecents(any())).thenAnswer((_) async {});
    when(() => serverRepo.saveWithPing(any())).thenAnswer((_) async {});
    when(() => serverRepo.cachedServers).thenReturn([]);
    // No update advertised by default; tests that exercise the updater stub
    // this getter themselves.
    when(() => serverRepo.cachedUpdateInfo)
        .thenReturn(AppUpdateInfo.none);
    when(() => settings.saveProtocol(any())).thenAnswer((_) async {});
  });

  VpnBloc build() => VpnBloc(
    fetchServers: FetchServers(serverRepo),
    refreshServers: RefreshServers(serverRepo),
    loadCached: LoadCachedServers(serverRepo),
    pingServers: PingServers(ping, ping),
    importActivation: ImportActivation(subs, serverRepo),
    startFreeTrial: StartFreeTrial(subs, serverRepo),
    subscribeWithCrypto: SubscribeWithCrypto(subs, serverRepo),
    signInWithGoogle: SignInWithGoogle(subs),
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
  });

  group('app update', () {
    final a = server(id: 1, ip: '1.1.1.1');
    final b = server(id: 2, ip: '2.2.2.2');

    blocTest<VpnBloc, VpnState>(
      'a fetch surfaces the advertised AppUpdateInfo on state',
      setUp: () {
        when(() => serverRepo.fetchServers())
            .thenAnswer((_) async => [a, b]);
        when(() => serverRepo.cachedUpdateInfo).thenReturn(
          const AppUpdateInfo(
            latestVersion: '2.4.0',
            minVersion: '2.3.0',
            updateUrl: 'https://example/release',
          ),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const VpnStarted()),
      verify: (bloc) {
        expect(bloc.state.appUpdateInfo.latestVersion, '2.4.0');
        expect(bloc.state.appUpdateInfo.minVersion, '2.3.0');
        expect(bloc.state.updateBannerDismissed, isFalse);
      },
    );

    blocTest<VpnBloc, VpnState>(
      'a newer latestVersion re-arms a previously dismissed banner',
      setUp: () {
        when(() => serverRepo.fetchServers())
            .thenAnswer((_) async => [a, b]);
        when(() => serverRepo.cachedUpdateInfo).thenReturn(
          const AppUpdateInfo(latestVersion: '2.4.1'),
        );
      },
      build: build,
      act: (bloc) async {
        // Seed a previously dismissed advisory for an older latest…
        bloc.add(const UpdateBannerDismissed());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const VpnStarted());
      },
      verify: (bloc) =>
          expect(bloc.state.updateBannerDismissed, isFalse),
    );

    blocTest<VpnBloc, VpnState>(
      'the same latestVersion keeps a dismissed banner dismissed',
      setUp: () {
        when(() => serverRepo.fetchServers())
            .thenAnswer((_) async => [a, b]);
        when(() => serverRepo.cachedUpdateInfo).thenReturn(
          const AppUpdateInfo(latestVersion: '2.4.1'),
        );
      },
      build: build,
      act: (bloc) async {
        // First fetch arms the advisory for 2.4.1…
        bloc.add(const VpnStarted());
        await Future<void>.delayed(Duration.zero);
        // …dismissing it, then fetching again (same latest) keeps it hidden.
        bloc.add(const UpdateBannerDismissed());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ServersFetchRequested());
      },
      verify: (bloc) =>
          expect(bloc.state.updateBannerDismissed, isTrue),
    );

    blocTest<VpnBloc, VpnState>(
      'UpdateBannerDismissed hides the advisory banner',
      build: build,
      act: (bloc) => bloc.add(const UpdateBannerDismissed()),
      verify: (bloc) =>
          expect(bloc.state.updateBannerDismissed, isTrue),
    );
  });

  group('expiry warning', () {
    // A plain test rather than blocTest: the warning message is one-shot and
    // gets overwritten by _onStarted's final `initialized: true` emit, so
    // asserting on final bloc.state would miss it — the states stream is
    // what a BlocListener actually reacts to.
    test('emits a message when 3 days or fewer remain', () async {
      when(() => subs.loadSubscription()).thenAnswer(
        (_) async => Subscription(
          expireTime: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      final bloc = build();
      final states = <VpnState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const VpnStarted());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      await bloc.close();

      final withMessage = states.where((s) => s.message != null);
      expect(withMessage, isNotEmpty);
      expect(withMessage.first.message!.isError, isFalse);
      verify(() => settings.saveLastExpiryWarningDate(any())).called(1);
    });

    blocTest<VpnBloc, VpnState>(
      'does not emit when more than 3 days remain',
      setUp: () => when(() => subs.loadSubscription()).thenAnswer(
        (_) async => Subscription(
          expireTime: DateTime.now().add(const Duration(days: 10)),
        ),
      ),
      build: build,
      act: (bloc) => bloc.add(const VpnStarted()),
      verify: (bloc) {
        expect(bloc.state.message, isNull);
        verifyNever(() => settings.saveLastExpiryWarningDate(any()));
      },
    );

    blocTest<VpnBloc, VpnState>(
      'does not repeat the same day',
      setUp: () {
        when(() => subs.loadSubscription()).thenAnswer(
          (_) async => Subscription(
            expireTime: DateTime.now().add(const Duration(days: 1)),
          ),
        );
        when(() => settings.getLastExpiryWarningDate())
            .thenAnswer((_) async => DateTime.now());
      },
      build: build,
      act: (bloc) => bloc.add(const VpnStarted()),
      verify: (bloc) {
        expect(bloc.state.message, isNull);
        verifyNever(() => settings.saveLastExpiryWarningDate(any()));
      },
    );
  });

  group('proxy sharing', () {
    blocTest<VpnBloc, VpnState>(
      'toggling persists enabled with the current port',
      build: build,
      act: (bloc) => bloc.add(const ProxySharingToggled(true)),
      verify: (bloc) {
        expect(bloc.state.proxySharingEnabled, isTrue);
        verify(() => settings.saveProxySharingSettings(
              enabled: true,
              port: 1080,
            )).called(1);
      },
    );

    blocTest<VpnBloc, VpnState>(
      'changing the port clamps to the valid range',
      build: build,
      act: (bloc) => bloc.add(const ProxySharingPortChanged(70000)),
      verify: (bloc) => expect(bloc.state.proxySharingPort, 65535),
    );

    blocTest<VpnBloc, VpnState>(
      'persist request saves the current enabled/port state',
      build: build,
      act: (bloc) => bloc
        ..add(const ProxySharingPortChanged(9050))
        ..add(const ProxySharingSettingsPersistRequested()),
      verify: (_) => verify(() => settings.saveProxySharingSettings(
            enabled: false,
            port: 9050,
          )).called(1),
    );
  });

  group('region pool', () {
    blocTest<VpnBloc, VpnState>(
      'toggling persists the choice immediately',
      build: build,
      act: (bloc) => bloc.add(const RegionPoolChanged(true)),
      verify: (bloc) {
        expect(bloc.state.useCuratedRegion, isTrue);
        verify(() => settings.saveUseCuratedRegion(true)).called(1);
      },
    );

    blocTest<VpnBloc, VpnState>(
      'defaults to the full list',
      build: build,
      act: (bloc) => bloc.add(const VpnStarted()),
      verify: (bloc) => expect(bloc.state.useCuratedRegion, isFalse),
    );
  });

  group('Google sign-in + sessions', () {
    blocTest<VpnBloc, VpnState>(
      'a successful sign-in stores the account and fetches servers',
      setUp: () => when(() => subs.signInWithGoogle()).thenAnswer(
        (_) async => const AuthSession(email: 'user@example.com'),
      ),
      build: build,
      act: (bloc) => bloc.add(const GoogleSignInRequested()),
      verify: (bloc) {
        expect(bloc.state.isSigningInWithGoogle, isFalse);
        expect(bloc.state.hasSession, isTrue);
        expect(bloc.state.email, 'user@example.com');
        verify(() => serverRepo.fetchServers()).called(1);
      },
    );

    blocTest<VpnBloc, VpnState>(
      'a cancelled sign-in leaves the state signed out',
      setUp: () =>
          when(() => subs.signInWithGoogle()).thenAnswer((_) async => null),
      build: build,
      act: (bloc) => bloc.add(const GoogleSignInRequested()),
      verify: (bloc) {
        expect(bloc.state.isSigningInWithGoogle, isFalse);
        expect(bloc.state.hasSession, isFalse);
      },
    );

    blocTest<VpnBloc, VpnState>(
      'a failed sign-in surfaces a message and resets the spinner',
      setUp: () =>
          when(() => subs.signInWithGoogle()).thenThrow(Exception('boom')),
      build: build,
      act: (bloc) => bloc.add(const GoogleSignInRequested()),
      verify: (bloc) {
        expect(bloc.state.isSigningInWithGoogle, isFalse);
        expect(bloc.state.hasSession, isFalse);
        expect(bloc.state.message, isNotNull);
      },
    );

    blocTest<VpnBloc, VpnState>(
      'sessions requested loads the account\'s device sessions',
      setUp: () => when(() => subs.listSessions()).thenAnswer(
        (_) async => const [
          UserSession(id: 1, deviceId: 'a', platform: 'android', active: true),
          UserSession(id: 2, deviceId: 'b', platform: 'linux', active: true),
        ],
      ),
      build: build,
      act: (bloc) => bloc.add(const SessionsRequested()),
      verify: (bloc) {
        expect(bloc.state.isLoadingSessions, isFalse);
        expect(bloc.state.sessions, hasLength(2));
      },
    );

    blocTest<VpnBloc, VpnState>(
      'revoking a session removes it and reloads the list',
      setUp: () {
        when(() => subs.revokeSession(2)).thenAnswer((_) async {});
        when(() => subs.listSessions()).thenAnswer(
          (_) async => const [
            UserSession(id: 1, deviceId: 'a', platform: 'android', active: true),
          ],
        );
      },
      build: build,
      act: (bloc) => bloc.add(const SessionRevoked(2)),
      verify: (bloc) {
        verify(() => subs.revokeSession(2)).called(1);
        expect(bloc.state.sessions, hasLength(1));
      },
    );

    blocTest<VpnBloc, VpnState>(
      'signing out clears the session and returns to onboarding',
      setUp: () => when(() => subs.signOut()).thenAnswer((_) async {}),
      build: build,
      seed: () => const VpnState(hasSession: true, email: 'user@example.com'),
      act: (bloc) => bloc.add(const SignOutRequested()),
      verify: (bloc) {
        expect(bloc.state.hasSession, isFalse);
        expect(bloc.state.email, isEmpty);
        verify(() => subs.signOut()).called(1);
      },
    );
  });

  group('Google account-link nudge', () {
    blocTest<VpnBloc, VpnState>(
      'a successful trial offers linking a Google account when not signed in',
      setUp: () {
        when(() => subs.startFreeTrial()).thenAnswer((_) async => []);
        when(() => subs.hasSeenGoogleLinkPrompt())
            .thenAnswer((_) async => false);
        when(() => subs.markGoogleLinkPromptSeen()).thenAnswer((_) async {});
      },
      build: build,
      seed: () => const VpnState(googleSignInAvailable: true),
      act: (bloc) => bloc.add(const FreeTrialRequested()),
      verify: (bloc) {
        expect(bloc.state.googleLinkNudge, isNotNull);
        verify(() => subs.markGoogleLinkPromptSeen()).called(1);
      },
    );

    blocTest<VpnBloc, VpnState>(
      'does not offer the nudge again once already seen',
      setUp: () {
        when(() => subs.startFreeTrial()).thenAnswer((_) async => []);
        when(() => subs.hasSeenGoogleLinkPrompt())
            .thenAnswer((_) async => true);
      },
      build: build,
      seed: () => const VpnState(googleSignInAvailable: true),
      act: (bloc) => bloc.add(const FreeTrialRequested()),
      verify: (bloc) {
        expect(bloc.state.googleLinkNudge, isNull);
        verifyNever(() => subs.markGoogleLinkPromptSeen());
      },
    );

    blocTest<VpnBloc, VpnState>(
      'does not offer the nudge when already signed in',
      setUp: () => when(() => subs.startFreeTrial()).thenAnswer((_) async => []),
      build: build,
      seed: () => const VpnState(
        googleSignInAvailable: true,
        hasSession: true,
        email: 'user@example.com',
      ),
      act: (bloc) => bloc.add(const FreeTrialRequested()),
      verify: (bloc) {
        expect(bloc.state.googleLinkNudge, isNull);
        verifyNever(() => subs.hasSeenGoogleLinkPrompt());
      },
    );
  });
}

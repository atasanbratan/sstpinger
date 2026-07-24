import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/app_update_info.dart';
import '../../../domain/entities/ping_mode.dart';
import '../../../domain/entities/ping_progress.dart';
import '../../../domain/entities/tunnel_protocol.dart';
import '../../../domain/entities/user_session.dart';
import '../../../domain/entities/vpn_server.dart';
import '../../../domain/failures/failures.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../domain/repositories/subscription_repository.dart';
import '../../../domain/repositories/vpn_server_repository.dart';
import '../../../domain/usecases/fetch_servers.dart';
import '../../../domain/usecases/import_activation.dart';
import '../../../domain/usecases/load_cached_servers.dart';
import '../../../domain/usecases/ping_servers.dart';
import '../../../domain/usecases/refresh_servers.dart';
import '../../../domain/usecases/sign_in_with_google.dart';
import '../../../domain/usecases/start_free_trial.dart';
import '../../../domain/usecases/subscribe_with_crypto.dart';

part 'vpn_event.dart';
part 'vpn_state.dart';

/// The cohesive VPN feature bloc: servers, ping, search, bookmarks, selection,
/// onboarding, subscription and username. The tunnel lifecycle lives separately
/// in [ConnectionBloc]; the screen coordinates the two (connected → refresh; the
/// ping guard reads connection status).
class VpnBloc extends Bloc<VpnEvent, VpnState> {
  final FetchServers _fetchServers;
  final RefreshServers _refreshServers;
  final LoadCachedServers _loadCached;
  final PingServers _pingServers;
  final ImportActivation _importActivation;
  final StartFreeTrial _startTrial;
  final SubscribeWithCrypto _subscribe;
  final SignInWithGoogle _signInWithGoogle;
  final VpnServerRepository _serverRepo;
  final SubscriptionRepository _subs;
  final SettingsRepository _settings;

  int _msgSeq = 0;
  int _actionSeq = 0;
  int _linkNudgeSeq = 0;

  VpnBloc({
    required FetchServers fetchServers,
    required RefreshServers refreshServers,
    required LoadCachedServers loadCached,
    required PingServers pingServers,
    required ImportActivation importActivation,
    required StartFreeTrial startFreeTrial,
    required SubscribeWithCrypto subscribeWithCrypto,
    required SignInWithGoogle signInWithGoogle,
    required VpnServerRepository serverRepository,
    required SubscriptionRepository subscriptionRepository,
    required SettingsRepository settingsRepository,
  }) : _fetchServers = fetchServers,
       _refreshServers = refreshServers,
       _loadCached = loadCached,
       _pingServers = pingServers,
       _importActivation = importActivation,
       _startTrial = startFreeTrial,
       _subscribe = subscribeWithCrypto,
       _signInWithGoogle = signInWithGoogle,
       _serverRepo = serverRepository,
       _subs = subscriptionRepository,
       _settings = settingsRepository,
       super(const VpnState()) {
    on<VpnStarted>(_onStarted);
    on<ServersFetchRequested>(_onFetch);
    on<ServersRefreshRequested>(_onRefresh);
    on<SearchQueryChanged>(_onSearch);
    on<ServerSelected>(_onSelect);
    on<BookmarkToggled>(_onBookmarkToggled);
    on<ServerConnected>(_onServerConnected);
    on<UseCustomConfigChanged>(_onUseCustomConfig);
    on<PingRequested>(_onPing);
    on<BookmarkPingRequested>(_onBookmarkPing);
    on<PingTimeoutChanged>(_onPingTimeout);
    on<PingBatchSizeChanged>(_onPingBatch);
    on<PingSettingsPersistRequested>(_onPersistPing);
    on<ReconnectRetryCountChanged>(_onReconnectCount);
    on<ReconnectRetryIntervalChanged>(_onReconnectInterval);
    on<ReconnectSettingsPersistRequested>(_onPersistReconnect);
    on<FetchServerCountChanged>(_onFetchServerCount);
    on<FetchServerCountPersistRequested>(_onPersistFetchServerCount);
    on<PingModeChanged>(_onPingMode);
    on<SoftEtherDisableNatTChanged>(_onSoftEtherDisableNatT);
    on<SoftEtherNatTRetryWaitChanged>(_onSoftEtherNatTRetryWait);
    on<SoftEtherNatTSettingsPersistRequested>(_onPersistSoftEtherNatT);
    on<ProxySharingToggled>(_onProxySharingToggled);
    on<ProxySharingPortChanged>(_onProxySharingPort);
    on<ProxySharingSettingsPersistRequested>(_onPersistProxySharing);
    on<RegionPoolChanged>(_onRegionPool);
    on<ServersViewModeChanged>(_onServersViewMode);
    on<ProtocolChanged>(_onProtocol);
    on<UsernameChanged>(_onUsername);
    on<ActivationCodeSubmitted>(_onActivation);
    on<FreeTrialRequested>(_onTrial);
    on<SubscriptionSubmitted>(_onSubscription);
    on<GoogleSignInRequested>(_onGoogleSignIn);
    on<SignOutRequested>(_onSignOut);
    on<SessionsRequested>(_onSessionsRequested);
    on<SessionRevoked>(_onSessionRevoked);
    on<UpdateBannerDismissed>(_onUpdateBannerDismissed);
  }

  Future<void> _onStarted(VpnStarted event, Emitter<VpnState> emit) async {
    final username = await _subs.getUsername();
    final deviceId = await _subs.getOrCreateDeviceId();
    final hasSession = await _subs.hasSession();
    final email = await _subs.getAccountEmail();
    final sub = await _subs.loadSubscription();
    final timeout = await _settings.getPingTimeoutMs();
    final batch = await _settings.getPingBatchSize();
    final retryCount = await _settings.getReconnectRetryCount();
    final retryInterval = await _settings.getReconnectRetryIntervalSeconds();
    final fetchCount = await _settings.getFetchServerCount();
    final pingMode = await _settings.getPingMode();
    final disableNatT = await _settings.getSoftEtherDisableNatT();
    final natTRetryWait = await _settings.getSoftEtherNatTRetryWaitSeconds();
    final proxySharingEnabled = await _settings.getProxySharingEnabled();
    final proxySharingPort = await _settings.getProxySharingPort();
    final useCuratedRegion = await _settings.getUseCuratedRegion();
    final flatView = await _settings.getServersFlatView();
    final protocol = await _settings.getProtocol();
    final bookmarks = await _serverRepo.loadBookmarks();
    final recents = await _serverRepo.loadRecents();
    final cached = await _loadCached();

    emit(
      state.copyWith(
        username: username,
        deviceId: deviceId,
        hasSession: hasSession,
        email: email,
        googleSignInAvailable: _subs.isGoogleSignInSupported,
        expireTime: sub.expireTime,
        lastFetchTime: sub.lastFetch,
        pingTimeoutMs: timeout,
        pingBatchSize: batch,
        reconnectRetryCount: retryCount,
        reconnectRetryIntervalSeconds: retryInterval,
        fetchServerCount: fetchCount,
        pingMode: pingMode,
        softEtherDisableNatT: disableNatT,
        softEtherNatTRetryWaitSeconds: natTRetryWait,
        proxySharingEnabled: proxySharingEnabled,
        proxySharingPort: proxySharingPort,
        useCuratedRegion: useCuratedRegion,
        serversFlatView: flatView,
        protocol: protocol,
        bookmarkedServers: bookmarks,
        recentServers: recents,
        servers: cached.isNotEmpty && state.servers.isEmpty
            ? cached
            : state.servers,
      ),
    );

    if (username.isNotEmpty || hasSession) {
      await _doFetch(emit);
    }
    emit(state.copyWith(initialized: true));
  }

  Future<void> _onFetch(ServersFetchRequested event, Emitter<VpnState> emit) =>
      _doFetch(emit);

  Future<void> _doFetch(Emitter<VpnState> emit) async {
    if (state.username.isEmpty && !state.hasSession) return;

    emit(state.copyWith(isFetchingServers: true));
    try {
      final servers = await _fetchServers();
      final sub = await _subs.loadSubscription();
      final selected = state.selectedServer ??
          (servers.isNotEmpty ? servers.first : null);
      emit(
        state.copyWith(
          servers: servers,
          isSubscriptionExpired: false,
          selectedServer: selected,
          expireTime: sub.expireTime,
          lastFetchTime: sub.lastFetch,
          isFetchingServers: false,
          appUpdateInfo: _serverRepo.cachedUpdateInfo,
          // A new latest version (or none at all) re-arms the advisory banner.
          updateBannerDismissed: _sameLatest(
            state.appUpdateInfo,
            _serverRepo.cachedUpdateInfo,
          )
              ? state.updateBannerDismissed
              : false,
        ),
      );
      await _maybeWarnExpiry(sub.expireTime, emit);
    } on SubscriptionExpiredException catch (e) {
      await _handleExpired(e.message, emit);
      emit(state.copyWith(isFetchingServers: false));
    } on ApiException catch (e) {
      emit(state.copyWith(isFetchingServers: false, message: _msg(e.message)));
    } catch (_) {
      emit(
        state.copyWith(
          isFetchingServers: false,
          message: _msg('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  /// Surfaces a one-shot "expires soon" banner when 0–3 days remain, at most
  /// once per calendar day (tracked via [SettingsRepository]).
  Future<void> _maybeWarnExpiry(
    DateTime? expireTime,
    Emitter<VpnState> emit,
  ) async {
    if (expireTime == null) return;
    final daysLeft = expireTime.difference(DateTime.now()).inDays;
    if (daysLeft < 0 || daysLeft > 3) return;

    final now = DateTime.now();
    final lastWarned = await _settings.getLastExpiryWarningDate();
    if (lastWarned != null && _isSameDay(lastWarned, now)) return;

    await _settings.saveLastExpiryWarningDate(now);
    emit(
      state.copyWith(
        message: _msg(
          daysLeft == 0
              ? 'Your subscription expires today.'
              : 'Your subscription expires in $daysLeft '
                    '${daysLeft == 1 ? 'day' : 'days'}.',
          isError: false,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _handleExpired(String message, Emitter<VpnState> emit) async {
    await _serverRepo.clearServers();
    emit(
      state.copyWith(
        isSubscriptionExpired: true,
        servers: const [],
        clearSelectedServer: true,
        message: _msg(message),
      ),
    );
  }

  Future<void> _onRefresh(
    ServersRefreshRequested event,
    Emitter<VpnState> emit,
  ) async {
    // Run at most once per session (after the first connect), and only if due.
    if (state.syncStatus != ServerSyncStatus.initial &&
        state.syncStatus != ServerSyncStatus.error) {
      return;
    }
    if (!_isRefreshDue()) {
      emit(state.copyWith(syncStatus: ServerSyncStatus.synced));
      return;
    }
    emit(state.copyWith(syncStatus: ServerSyncStatus.loading));
    await Future<void>.delayed(const Duration(seconds: 1));
    try {
      final merged = await _refreshServers();
      emit(
        state.copyWith(
          servers: merged,
          isSubscriptionExpired: false,
          syncStatus: ServerSyncStatus.synced,
          appUpdateInfo: _serverRepo.cachedUpdateInfo,
          updateBannerDismissed: _sameLatest(
            state.appUpdateInfo,
            _serverRepo.cachedUpdateInfo,
          )
              ? state.updateBannerDismissed
              : false,
        ),
      );
    } on SubscriptionExpiredException catch (e) {
      await _handleExpired(e.message, emit);
      emit(state.copyWith(syncStatus: ServerSyncStatus.error));
    } catch (_) {
      emit(state.copyWith(syncStatus: ServerSyncStatus.error));
    }
  }

  bool _isRefreshDue() {
    final last = state.lastFetchTime;
    if (last == null) return true;
    return DateTime.now().difference(last) >= const Duration(days: 1);
  }

  void _onSearch(SearchQueryChanged event, Emitter<VpnState> emit) =>
      emit(state.copyWith(searchQuery: event.query));

  void _onSelect(ServerSelected event, Emitter<VpnState> emit) =>
      emit(state.copyWith(useCustomConfig: false, selectedServer: event.server));

  Future<void> _onBookmarkToggled(
    BookmarkToggled event,
    Emitter<VpnState> emit,
  ) async {
    final list = List<VpnServer>.from(state.bookmarkedServers);
    final index = list.indexWhere((b) => b.endpoint == event.server.endpoint);
    if (index != -1) {
      list.removeAt(index);
    } else {
      list.add(event.server);
    }
    emit(state.copyWith(bookmarkedServers: list));
    await _serverRepo.saveBookmarks(list);
  }

  /// How many recently-connected servers to keep.
  static const int _maxRecents = 20;

  Future<void> _onServerConnected(
    ServerConnected event,
    Emitter<VpnState> emit,
  ) async {
    // Newest first, de-duplicated by endpoint, capped.
    final list = List<VpnServer>.from(state.recentServers)
      ..removeWhere((s) => s.endpoint == event.server.endpoint)
      ..insert(0, event.server);
    if (list.length > _maxRecents) list.removeRange(_maxRecents, list.length);
    emit(state.copyWith(recentServers: list));
    await _serverRepo.saveRecents(list);
  }

  void _onUseCustomConfig(UseCustomConfigChanged event, Emitter<VpnState> emit) =>
      emit(state.copyWith(useCustomConfig: event.useCustomConfig));

  Future<void> _onPing(PingRequested event, Emitter<VpnState> emit) async {
    if (event.isConnected) {
      emit(
        state.copyWith(
          message: _msg(
            "You can't ping servers while connected. Disconnect the VPN first.",
          ),
        ),
      );
      return;
    }
    if (state.isPinging || state.servers.isEmpty) return;

    final source = List<VpnServer>.from(state.servers);
    emit(
      state.copyWith(
        isPinging: true,
        pingProgress: 0,
        pingTotal: source.length,
        servers: const [],
      ),
    );

    await emit.forEach<PingProgress>(
      _pingServers(
        source,
        timeoutMs: state.pingTimeoutMs,
        batchSize: state.pingBatchSize,
        mode: state.pingMode,
      ),
      onData: (p) => state.copyWith(
        servers: p.servers,
        pingProgress: p.done,
        pingTotal: p.total,
      ),
    );

    final sorted = List<VpnServer>.from(state.servers)
      ..sort((a, b) => (a.ping ?? 999999).compareTo(b.ping ?? 999999));
    emit(state.copyWith(servers: sorted, isPinging: false));
    await _serverRepo.saveWithPing(sorted);
  }

  Future<void> _onBookmarkPing(
    BookmarkPingRequested event,
    Emitter<VpnState> emit,
  ) async {
    if (event.isConnected) {
      emit(
        state.copyWith(
          message: _msg(
            "You can't ping servers while connected. Disconnect the VPN first.",
          ),
        ),
      );
      return;
    }
    if (state.isPinging) return;
    final targets = List<VpnServer>.from(state.bookmarkedServers);
    if (targets.isEmpty) return;

    emit(
      state.copyWith(isPinging: true, pingProgress: 0, pingTotal: targets.length),
    );

    await emit.forEach<PingProgress>(
      _pingServers(
        targets,
        timeoutMs: state.pingTimeoutMs,
        batchSize: state.pingBatchSize,
        mode: state.pingMode,
      ),
      onData: (p) => state.copyWith(
        bookmarkedServers: _mergePings(state.bookmarkedServers, p.servers),
        servers: _mergePings(state.servers, p.servers),
        pingProgress: p.done,
        pingTotal: p.total,
      ),
    );

    emit(state.copyWith(isPinging: false));
    await _serverRepo.saveBookmarks(state.bookmarkedServers);
    await _serverRepo.saveWithPing(state.servers);
  }

  /// Copies the freshly measured latencies from [pinged] into [list], matching on
  /// endpoint. A probed server that did not answer gets its latency cleared —
  /// keeping a stale value would misreport what the sweep actually found.
  List<VpnServer> _mergePings(List<VpnServer> list, List<VpnServer> pinged) {
    final probed = {for (final s in pinged) s.endpoint: s.ping};
    return [
      for (final s in list)
        probed.containsKey(s.endpoint) ? s.withPing(probed[s.endpoint]) : s,
    ];
  }

  void _onPingTimeout(PingTimeoutChanged event, Emitter<VpnState> emit) =>
      emit(state.copyWith(pingTimeoutMs: (event.seconds * 1000).round()));

  void _onPingBatch(PingBatchSizeChanged event, Emitter<VpnState> emit) =>
      emit(state.copyWith(pingBatchSize: event.size < 1 ? 1 : event.size));

  Future<void> _onPersistPing(
    PingSettingsPersistRequested event,
    Emitter<VpnState> emit,
  ) => _settings.savePingSettings(
    timeoutMs: state.pingTimeoutMs,
    batchSize: state.pingBatchSize,
  );

  void _onReconnectCount(
    ReconnectRetryCountChanged event,
    Emitter<VpnState> emit,
  ) => emit(state.copyWith(reconnectRetryCount: event.count.clamp(0, 20)));

  void _onReconnectInterval(
    ReconnectRetryIntervalChanged event,
    Emitter<VpnState> emit,
  ) => emit(state.copyWith(
    reconnectRetryIntervalSeconds: event.seconds.clamp(1, 60),
  ));

  Future<void> _onPersistReconnect(
    ReconnectSettingsPersistRequested event,
    Emitter<VpnState> emit,
  ) => _settings.saveReconnectSettings(
    retryCount: state.reconnectRetryCount,
    retryIntervalSeconds: state.reconnectRetryIntervalSeconds,
  );

  void _onFetchServerCount(
    FetchServerCountChanged event,
    Emitter<VpnState> emit,
  ) => emit(state.copyWith(fetchServerCount: event.count.clamp(50, 5000)));

  Future<void> _onPersistFetchServerCount(
    FetchServerCountPersistRequested event,
    Emitter<VpnState> emit,
  ) => _settings.saveFetchServerCount(state.fetchServerCount);

  Future<void> _onPingMode(
    PingModeChanged event,
    Emitter<VpnState> emit,
  ) async {
    emit(state.copyWith(pingMode: event.mode));
    await _settings.savePingMode(event.mode);
  }

  Future<void> _onProxySharingToggled(
    ProxySharingToggled event,
    Emitter<VpnState> emit,
  ) async {
    emit(state.copyWith(proxySharingEnabled: event.enabled));
    await _settings.saveProxySharingSettings(
      enabled: event.enabled,
      port: state.proxySharingPort,
    );
  }

  void _onProxySharingPort(
    ProxySharingPortChanged event,
    Emitter<VpnState> emit,
  ) => emit(state.copyWith(proxySharingPort: event.port.clamp(1024, 65535)));

  Future<void> _onPersistProxySharing(
    ProxySharingSettingsPersistRequested event,
    Emitter<VpnState> emit,
  ) => _settings.saveProxySharingSettings(
    enabled: state.proxySharingEnabled,
    port: state.proxySharingPort,
  );

  Future<void> _onRegionPool(
    RegionPoolChanged event,
    Emitter<VpnState> emit,
  ) async {
    emit(state.copyWith(useCuratedRegion: event.useCuratedRegion));
    await _settings.saveUseCuratedRegion(event.useCuratedRegion);
  }

  void _onSoftEtherDisableNatT(
    SoftEtherDisableNatTChanged event,
    Emitter<VpnState> emit,
  ) => emit(state.copyWith(softEtherDisableNatT: event.disable));

  void _onSoftEtherNatTRetryWait(
    SoftEtherNatTRetryWaitChanged event,
    Emitter<VpnState> emit,
  ) => emit(state.copyWith(
    softEtherNatTRetryWaitSeconds: event.seconds.clamp(5, 60),
  ));

  Future<void> _onPersistSoftEtherNatT(
    SoftEtherNatTSettingsPersistRequested event,
    Emitter<VpnState> emit,
  ) => _settings.saveSoftEtherNatTSettings(
    disableNatT: state.softEtherDisableNatT,
    retryWaitSeconds: state.softEtherNatTRetryWaitSeconds,
  );

  Future<void> _onServersViewMode(
    ServersViewModeChanged event,
    Emitter<VpnState> emit,
  ) async {
    emit(state.copyWith(serversFlatView: event.flat));
    await _settings.saveServersFlatView(event.flat);
  }

  Future<void> _onProtocol(
    ProtocolChanged event,
    Emitter<VpnState> emit,
  ) async {
    // Only implemented protocols can be selected; ignore the rest (the picker
    // shows them disabled, this guards against a stray event).
    if (!event.protocol.available) return;
    emit(state.copyWith(protocol: event.protocol));
    await _settings.saveProtocol(event.protocol);
  }

  Future<void> _onUsername(UsernameChanged event, Emitter<VpnState> emit) async {
    final trimmed = event.username.trim();
    if (trimmed.isEmpty) return;
    await _subs.saveUsername(trimmed);
    emit(state.copyWith(username: trimmed));
    await _doFetch(emit);
  }

  Future<void> _onActivation(
    ActivationCodeSubmitted event,
    Emitter<VpnState> emit,
  ) async {
    if (state.isImportingActivation) return;
    emit(state.copyWith(isImportingActivation: true));
    try {
      await _importActivation(event.base64);
    } catch (_) {
      emit(
        state.copyWith(
          isImportingActivation: false,
          message: _msg(
            'Invalid activation code. Please check the code and try again.',
          ),
          actionResult: _action(VpnActionKind.activation, false),
        ),
      );
      return;
    }
    await _afterUnlock(VpnActionKind.activation, emit, clearActivation: true);
  }

  Future<void> _onTrial(FreeTrialRequested event, Emitter<VpnState> emit) async {
    if (state.isStartingTrial) return;
    emit(state.copyWith(isStartingTrial: true));
    try {
      await _startTrial();
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isStartingTrial: false,
          message: _msg(e.message),
          actionResult: _action(VpnActionKind.trial, false),
        ),
      );
      return;
    } catch (_) {
      emit(
        state.copyWith(
          isStartingTrial: false,
          message: _msg('Could not start your free trial. Please try again.'),
          actionResult: _action(VpnActionKind.trial, false),
        ),
      );
      return;
    }
    await _afterUnlock(VpnActionKind.trial, emit, clearTrial: true);
  }

  Future<void> _onSubscription(
    SubscriptionSubmitted event,
    Emitter<VpnState> emit,
  ) async {
    if (state.isSubmittingSubscription) return;
    emit(state.copyWith(isSubmittingSubscription: true));
    try {
      await _subscribe(network: event.network, txHash: event.txHash);
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isSubmittingSubscription: false,
          message: _msg(e.message),
          actionResult: _action(VpnActionKind.subscription, false),
        ),
      );
      return;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmittingSubscription: false,
          message: _msg('Could not verify your payment. Please try again.'),
          actionResult: _action(VpnActionKind.subscription, false),
        ),
      );
      return;
    }
    await _afterUnlock(VpnActionKind.subscription, emit, clearSubscribing: true);
  }

  Future<void> _onGoogleSignIn(
    GoogleSignInRequested event,
    Emitter<VpnState> emit,
  ) async {
    if (state.isSigningInWithGoogle) return;
    emit(state.copyWith(isSigningInWithGoogle: true));

    try {
      final session = await _signInWithGoogle();
      if (session == null) {
        // User cancelled the Google sign-in sheet.
        emit(state.copyWith(isSigningInWithGoogle: false));
        return;
      }
      emit(
        state.copyWith(
          isSigningInWithGoogle: false,
          hasSession: true,
          email: session.email,
          expireTime: session.expireTime,
        ),
      );
      // Pull the server list for the account. A brand-new account with no
      // entitlement yet surfaces SUBSCRIPTION_EXPIRED here, which keeps the
      // onboarding gate open so the user can start a trial/subscription — now
      // attached to their Google account.
      await _doFetch(emit);
    } on ApiException catch (e) {
      emit(state.copyWith(isSigningInWithGoogle: false, message: _msg(e.message)));
    } catch (_) {
      emit(
        state.copyWith(
          isSigningInWithGoogle: false,
          message: _msg('Google sign-in failed. Please try again.'),
        ),
      );
    }
  }

  Future<void> _onSignOut(SignOutRequested event, Emitter<VpnState> emit) async {
    await _subs.signOut();
    await _serverRepo.clearServers();
    emit(
      state.copyWith(
        hasSession: false,
        email: '',
        servers: const [],
        sessions: const [],
        isSubscriptionExpired: false,
        clearSelectedServer: true,
      ),
    );
  }

  Future<void> _onSessionsRequested(
    SessionsRequested event,
    Emitter<VpnState> emit,
  ) async {
    emit(state.copyWith(isLoadingSessions: true));
    try {
      final sessions = await _subs.listSessions();
      emit(state.copyWith(sessions: sessions, isLoadingSessions: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingSessions: false,
          message: _msg('Could not load your sessions. Please try again.'),
        ),
      );
    }
  }

  Future<void> _onSessionRevoked(
    SessionRevoked event,
    Emitter<VpnState> emit,
  ) async {
    try {
      await _subs.revokeSession(event.sessionId);
      final sessions = await _subs.listSessions();
      emit(state.copyWith(sessions: sessions));
    } catch (_) {
      emit(state.copyWith(message: _msg('Could not revoke that session.')));
    }
  }

  /// Shared tail of the three unlock flows: refresh identity/servers from the
  /// just-imported activation, then ping.
  Future<void> _afterUnlock(
    VpnActionKind kind,
    Emitter<VpnState> emit, {
    bool clearActivation = false,
    bool clearTrial = false,
    bool clearSubscribing = false,
  }) async {
    final username = await _subs.getUsername();
    final servers = _serverRepo.cachedServers;
    final selected =
        state.selectedServer ?? (servers.isNotEmpty ? servers.first : null);
    emit(
      state.copyWith(
        isImportingActivation: clearActivation ? false : null,
        isStartingTrial: clearTrial ? false : null,
        isSubmittingSubscription: clearSubscribing ? false : null,
        isSubscriptionExpired: false,
        username: username,
        servers: servers,
        selectedServer: selected,
        actionResult: _action(kind, true),
      ),
    );
    add(const PingRequested(isConnected: false));
    await _maybeOfferGoogleLink(kind, emit);
  }

  /// Offers linking a Google account at most once, right after a trial or
  /// subscription succeeds while the user isn't signed in — so access is
  /// recoverable across reinstalls without gating trial/payment on sign-in
  /// (unlike the account itself, an activation code isn't tied to a device).
  Future<void> _maybeOfferGoogleLink(
    VpnActionKind kind,
    Emitter<VpnState> emit,
  ) async {
    if (kind != VpnActionKind.trial && kind != VpnActionKind.subscription) {
      return;
    }
    if (state.hasSession || !state.googleSignInAvailable) return;
    if (await _subs.hasSeenGoogleLinkPrompt()) return;
    await _subs.markGoogleLinkPromptSeen();
    emit(state.copyWith(googleLinkNudge: VpnGoogleLinkNudge(++_linkNudgeSeq)));
  }

  VpnMessage _msg(String text, {bool isError = true}) =>
      VpnMessage(++_msgSeq, text, isError: isError);

  VpnActionResult _action(VpnActionKind kind, bool success) =>
      VpnActionResult(++_actionSeq, kind, success);

  void _onUpdateBannerDismissed(
    UpdateBannerDismissed event,
    Emitter<VpnState> emit,
  ) => emit(state.copyWith(updateBannerDismissed: true));

  /// Whether [a] and [b] advertise the same advisory version. Null-safe: a
  /// transition into/out of `none` counts as a change so the banner re-arms.
  bool _sameLatest(AppUpdateInfo a, AppUpdateInfo b) =>
      a.latestVersion == b.latestVersion;
}

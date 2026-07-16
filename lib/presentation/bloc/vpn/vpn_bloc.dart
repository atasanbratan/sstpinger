import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/ping_progress.dart';
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
  final VpnServerRepository _serverRepo;
  final SubscriptionRepository _subs;
  final SettingsRepository _settings;

  int _msgSeq = 0;
  int _actionSeq = 0;

  VpnBloc({
    required FetchServers fetchServers,
    required RefreshServers refreshServers,
    required LoadCachedServers loadCached,
    required PingServers pingServers,
    required ImportActivation importActivation,
    required StartFreeTrial startFreeTrial,
    required SubscribeWithCrypto subscribeWithCrypto,
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
    on<UseCustomConfigChanged>(_onUseCustomConfig);
    on<PingRequested>(_onPing);
    on<BookmarkPingRequested>(_onBookmarkPing);
    on<PingTimeoutChanged>(_onPingTimeout);
    on<PingBatchSizeChanged>(_onPingBatch);
    on<PingSettingsPersistRequested>(_onPersistPing);
    on<ReconnectRetryCountChanged>(_onReconnectCount);
    on<ReconnectRetryIntervalChanged>(_onReconnectInterval);
    on<ReconnectSettingsPersistRequested>(_onPersistReconnect);
    on<UsernameChanged>(_onUsername);
    on<ActivationCodeSubmitted>(_onActivation);
    on<FreeTrialRequested>(_onTrial);
    on<SubscriptionSubmitted>(_onSubscription);
  }

  Future<void> _onStarted(VpnStarted event, Emitter<VpnState> emit) async {
    final username = await _subs.getUsername();
    final deviceId = await _subs.getOrCreateDeviceId();
    final sub = await _subs.loadSubscription();
    final timeout = await _settings.getPingTimeoutMs();
    final batch = await _settings.getPingBatchSize();
    final retryCount = await _settings.getReconnectRetryCount();
    final retryInterval = await _settings.getReconnectRetryIntervalSeconds();
    final bookmarks = await _serverRepo.loadBookmarks();
    final cached = await _loadCached();

    emit(
      state.copyWith(
        username: username,
        deviceId: deviceId,
        expireTime: sub.expireTime,
        lastFetchTime: sub.lastFetch,
        pingTimeoutMs: timeout,
        pingBatchSize: batch,
        reconnectRetryCount: retryCount,
        reconnectRetryIntervalSeconds: retryInterval,
        bookmarkedServers: bookmarks,
        servers: cached.isNotEmpty && state.servers.isEmpty
            ? cached
            : state.servers,
      ),
    );

    if (username.isNotEmpty) {
      await _doFetch(emit);
    }
    emit(state.copyWith(initialized: true));
  }

  Future<void> _onFetch(ServersFetchRequested event, Emitter<VpnState> emit) =>
      _doFetch(emit);

  Future<void> _doFetch(Emitter<VpnState> emit) async {
    if (state.username.isEmpty) return;

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
        ),
      );
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
  }

  VpnMessage _msg(String text, {bool isError = true}) =>
      VpnMessage(++_msgSeq, text, isError: isError);

  VpnActionResult _action(VpnActionKind kind, bool success) =>
      VpnActionResult(++_actionSeq, kind, success);
}

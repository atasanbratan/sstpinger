part of 'vpn_bloc.dart';

/// A one-shot user message (error or info) for the screen to surface as a
/// SnackBar. The incrementing [id] makes two identical messages still register
/// as a change (Equatable compares only the id).
class VpnMessage extends Equatable {
  final int id;
  final String text;
  final bool isError;
  const VpnMessage(this.id, this.text, {this.isError = true});

  @override
  List<Object?> get props => [id];
}

enum VpnActionKind { activation, trial, subscription }

/// The one-shot outcome of an onboarding action (activation / trial /
/// subscription), so a screen can navigate or pop on success.
class VpnActionResult extends Equatable {
  final int id;
  final VpnActionKind kind;
  final bool success;
  const VpnActionResult(this.id, this.kind, this.success);

  @override
  List<Object?> get props => [id];
}

/// Tracks whether the post-connect background server refresh has run, so it only
/// happens once per session.
enum ServerSyncStatus { initial, loading, synced, error }

class VpnState extends Equatable {
  final bool initialized;
  final String username;
  final String deviceId;

  final List<VpnServer> servers;
  final bool isFetchingServers;
  final bool isSubscriptionExpired;
  final DateTime? expireTime;
  final DateTime? lastFetchTime;

  final String searchQuery;
  final VpnServer? selectedServer;
  final bool useCustomConfig;
  final List<VpnServer> bookmarkedServers;

  /// Recently-connected servers, newest first (capped, de-duplicated).
  final List<VpnServer> recentServers;

  final bool isPinging;
  final int pingProgress;
  final int pingTotal;
  final int pingTimeoutMs;
  final int pingBatchSize;

  /// Auto-reconnection policy (consumed by ConnectionBloc via the settings repo;
  /// held here so the settings sheet can display and edit it). 0 count disables.
  final int reconnectRetryCount;
  final int reconnectRetryIntervalSeconds;

  /// Servers-tab layout: true = flat, ping-sorted list; false = grouped by country.
  final bool serversFlatView;

  /// The selected tunnel protocol (only SSTP connects today).
  final TunnelProtocol protocol;

  final bool isImportingActivation;
  final bool isStartingTrial;
  final bool isSubmittingSubscription;

  final VpnMessage? message;
  final VpnActionResult? actionResult;
  final ServerSyncStatus syncStatus;

  const VpnState({
    this.initialized = false,
    this.username = '',
    this.deviceId = '',
    this.servers = const [],
    this.isFetchingServers = false,
    this.isSubscriptionExpired = false,
    this.expireTime,
    this.lastFetchTime,
    this.searchQuery = '',
    this.selectedServer,
    this.useCustomConfig = false,
    this.bookmarkedServers = const [],
    this.recentServers = const [],
    this.isPinging = false,
    this.pingProgress = 0,
    this.pingTotal = 0,
    this.pingTimeoutMs = 1500,
    this.pingBatchSize = 25,
    this.reconnectRetryCount = 3,
    this.reconnectRetryIntervalSeconds = 5,
    this.serversFlatView = false,
    this.protocol = TunnelProtocol.sstp,
    this.isImportingActivation = false,
    this.isStartingTrial = false,
    this.isSubmittingSubscription = false,
    this.message,
    this.actionResult,
    this.syncStatus = ServerSyncStatus.initial,
  });

  int get pingPercent =>
      pingTotal == 0 ? 0 : ((pingProgress / pingTotal) * 100).round();

  double get pingTimeoutSeconds => pingTimeoutMs / 1000;

  bool isBookmarked(VpnServer server) =>
      bookmarkedServers.any((b) => b.endpoint == server.endpoint);

  /// Whether the onboarding gate should show (no identity yet, or lapsed).
  bool get needsOnboarding => username.isEmpty || isSubscriptionExpired;

  List<VpnServer> get filteredServers {
    if (searchQuery.trim().isEmpty) return servers;
    final q = searchQuery.toLowerCase();
    return servers
        .where(
          (s) =>
              s.country.toLowerCase().contains(q) ||
              s.hostname.toLowerCase().contains(q),
        )
        .toList();
  }

  VpnState copyWith({
    bool? initialized,
    String? username,
    String? deviceId,
    List<VpnServer>? servers,
    bool? isFetchingServers,
    bool? isSubscriptionExpired,
    DateTime? expireTime,
    DateTime? lastFetchTime,
    String? searchQuery,
    VpnServer? selectedServer,
    bool clearSelectedServer = false,
    bool? useCustomConfig,
    List<VpnServer>? bookmarkedServers,
    List<VpnServer>? recentServers,
    bool? isPinging,
    int? pingProgress,
    int? pingTotal,
    int? pingTimeoutMs,
    int? pingBatchSize,
    int? reconnectRetryCount,
    int? reconnectRetryIntervalSeconds,
    bool? serversFlatView,
    TunnelProtocol? protocol,
    bool? isImportingActivation,
    bool? isStartingTrial,
    bool? isSubmittingSubscription,
    VpnMessage? message,
    VpnActionResult? actionResult,
    ServerSyncStatus? syncStatus,
  }) {
    return VpnState(
      initialized: initialized ?? this.initialized,
      username: username ?? this.username,
      deviceId: deviceId ?? this.deviceId,
      servers: servers ?? this.servers,
      isFetchingServers: isFetchingServers ?? this.isFetchingServers,
      isSubscriptionExpired:
          isSubscriptionExpired ?? this.isSubscriptionExpired,
      expireTime: expireTime ?? this.expireTime,
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedServer: clearSelectedServer
          ? null
          : (selectedServer ?? this.selectedServer),
      useCustomConfig: useCustomConfig ?? this.useCustomConfig,
      bookmarkedServers: bookmarkedServers ?? this.bookmarkedServers,
      recentServers: recentServers ?? this.recentServers,
      isPinging: isPinging ?? this.isPinging,
      pingProgress: pingProgress ?? this.pingProgress,
      pingTotal: pingTotal ?? this.pingTotal,
      pingTimeoutMs: pingTimeoutMs ?? this.pingTimeoutMs,
      pingBatchSize: pingBatchSize ?? this.pingBatchSize,
      reconnectRetryCount: reconnectRetryCount ?? this.reconnectRetryCount,
      reconnectRetryIntervalSeconds:
          reconnectRetryIntervalSeconds ?? this.reconnectRetryIntervalSeconds,
      serversFlatView: serversFlatView ?? this.serversFlatView,
      protocol: protocol ?? this.protocol,
      isImportingActivation:
          isImportingActivation ?? this.isImportingActivation,
      isStartingTrial: isStartingTrial ?? this.isStartingTrial,
      isSubmittingSubscription:
          isSubmittingSubscription ?? this.isSubmittingSubscription,
      // message/actionResult are one-shot: not carried forward unless re-set.
      message: message,
      actionResult: actionResult,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  List<Object?> get props => [
    initialized,
    username,
    deviceId,
    servers,
    isFetchingServers,
    isSubscriptionExpired,
    expireTime,
    lastFetchTime,
    searchQuery,
    selectedServer,
    useCustomConfig,
    bookmarkedServers,
    recentServers,
    isPinging,
    pingProgress,
    pingTotal,
    pingTimeoutMs,
    pingBatchSize,
    reconnectRetryCount,
    reconnectRetryIntervalSeconds,
    serversFlatView,
    protocol,
    isImportingActivation,
    isStartingTrial,
    isSubmittingSubscription,
    message,
    actionResult,
    syncStatus,
  ];
}

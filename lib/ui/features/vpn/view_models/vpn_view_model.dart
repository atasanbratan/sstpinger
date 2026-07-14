import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../data/models/tunnel_traffic.dart';
import '../../../../data/models/vpn_server.dart';
import '../../../../data/repositories/vpn_repository.dart';
import '../../../../data/services/api_exception.dart';
import '../../../../data/services/ping_service.dart';
import '../../../../data/services/vpn_api_client.dart';
import '../../../../data/services/vpn_tunnel_service.dart';

class SSTPConnectionStatusKeys {
  static const String connected = VpnTunnelStatus.connected;
  static const String connecting = VpnTunnelStatus.connecting;
  static const String disconnected = VpnTunnelStatus.disconnected;
  static const String disconnecting = VpnTunnelStatus.disconnecting;
}

enum ServerSyncStatus { initial, loading, synced, error }

class VpnViewModel extends ChangeNotifier {
  final VpnRepository _repository;
  final PingService _pingService = const PingService();

  /// The tunnel. Which plugin actually carries it — `sstp_flutter` on mobile,
  /// `sstp_vpn_plugin` on desktop — is decided by the factory, and nothing in
  /// this class or the widgets above it knows or cares.
  final VpnTunnelService _tunnel;

  // Callbacks
  void Function(String)? onErrorMessage;

  // State fields
  bool _isPinging = false;
  bool get isPinging => _isPinging;

  // Live ping progress (updated as each server is probed).
  int _pingProgress = 0;
  int get pingProgress => _pingProgress;
  int _pingTotal = 0;
  int get pingTotal => _pingTotal;
  int get pingPercent =>
      _pingTotal == 0 ? 0 : ((_pingProgress / _pingTotal) * 100).round();

  // Ping tuning (persisted). Timeout is the max wait per server; batch size is
  // the number of servers probed concurrently.
  int _pingTimeoutMs = 1500;
  int _pingBatchSize = 25;
  double get pingTimeoutSeconds => _pingTimeoutMs / 1000;
  int get pingBatchSize => _pingBatchSize;

  bool _initialized = false;
  bool get initialized => _initialized;

  String _username = '';
  String get username => _username;

  String _deviceId = '';
  String get deviceId => _deviceId;

  List<VpnServer> _servers = [];
  List<VpnServer> get servers => _servers;

  bool _isFetchingServers = false;
  bool get isFetchingServers => _isFetchingServers;

  String? _serverFetchError;
  String? get serverFetchError => _serverFetchError;

  bool _isSubscriptionExpired = false;
  bool get isSubscriptionExpired => _isSubscriptionExpired;

  DateTime? get expireTime => _repository.expireTime;
  DateTime? get lastFetchTime => _repository.lastFetchTime;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _connectionStatus = SSTPConnectionStatusKeys.disconnected;
  String get connectionStatus => _connectionStatus;

  bool get isConnected =>
      _connectionStatus == SSTPConnectionStatusKeys.connected ||
      _connectionStatus == SSTPConnectionStatusKeys.connecting;

  TunnelTraffic? _traffic;
  TunnelTraffic? get traffic => _traffic;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  VpnServer? _selectedServer;
  VpnServer? get selectedServer => _selectedServer;

  bool _useCustomConfig = false;
  bool get useCustomConfig => _useCustomConfig;

  // Servers the user has bookmarked to connect to later. Stored independently
  // of [_servers] so a refetch never makes a bookmark disappear.
  List<VpnServer> _bookmarkedServers = [];
  List<VpnServer> get bookmarkedServers => _bookmarkedServers;
  bool isBookmarked(VpnServer server) =>
      _bookmarkedServers.any((b) => b.endpoint == server.endpoint);

  ServerSyncStatus _hasSyncedServers = ServerSyncStatus.initial;

  // Controllers for Custom Config
  final TextEditingController customHostController = TextEditingController();
  final TextEditingController customPortController = TextEditingController(
    text: '443',
  );
  final TextEditingController customUsernameController = TextEditingController(
    text: 'vpn',
  );
  final TextEditingController customPasswordController = TextEditingController(
    text: 'vpn',
  );

  /// [tunnel] is injectable so tests can drive the VM with a fake instead of a
  /// real VPN; it defaults to the implementation for the running platform.
  VpnViewModel({required this._repository, VpnTunnelService? tunnel})
    : _tunnel = tunnel ?? VpnTunnelService.forPlatform() {
    _init();
  }

  @override
  void dispose() {
    _tunnel.dispose();
    customHostController.dispose();
    customPortController.dispose();
    customUsernameController.dispose();
    customPasswordController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _username = await _repository.getUsername();
    _deviceId = await _repository.getOrCreateDeviceId();
    await _repository.loadSubscriptionInfo();
    _pingTimeoutMs = await _repository.getPingTimeoutMs();
    _pingBatchSize = await _repository.getPingBatchSize();
    _bookmarkedServers = await _repository.loadBookmarkedServers();
    await _checkLastStatus();
    _setupSstpListener();
    _loadCachedServers();
    if (_username.isNotEmpty) {
      await fetchServers();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _checkLastStatus() async {
    try {
      _connectionStatus = await _tunnel.lastConnectionStatus();
    } catch (e) {
      debugPrint('Error checking last connection status: $e');
    }
  }

  void _setupSstpListener() {
    _tunnel.onResult(
      onConnected: (TunnelTraffic? traffic, Duration duration) {
        _connectionStatus = SSTPConnectionStatusKeys.connected;
        _traffic = traffic;
        _duration = duration;
        notifyListeners();

        if ([
          ServerSyncStatus.initial,
          ServerSyncStatus.error,
        ].contains(_hasSyncedServers)) {
          if (!_isServerRefreshDue) {
            // Servers were already downloaded within the last day, so skip the
            // network fetch while connected and treat them as up to date.
            _hasSyncedServers = ServerSyncStatus.synced;
          } else {
            _hasSyncedServers = ServerSyncStatus.loading;

            unawaited(
              Future.delayed(const Duration(seconds: 1), _refreshServers)
                  .then(
                    (e) => switch (e) {
                      true => ServerSyncStatus.synced,
                      false => ServerSyncStatus.error,
                    },
                  )
                  .then((e) => _hasSyncedServers = e)
                  .then((_) => notifyListeners()),
            );
          }
        }
      },
      onConnecting: () {
        _connectionStatus = SSTPConnectionStatusKeys.connecting;
        notifyListeners();
      },
      onDisconnected: () {
        _connectionStatus = SSTPConnectionStatusKeys.disconnected;
        _traffic = null;
        _duration = Duration.zero;
        notifyListeners();
      },
      // The message comes from the service, which is the only layer that knows
      // *why* it failed — a missing capability on Linux and a missing
      // Administrator token on Windows need different advice.
      onError: (String message) {
        _connectionStatus = SSTPConnectionStatusKeys.disconnected;
        _traffic = null;
        _duration = Duration.zero;
        notifyListeners();
        onErrorMessage?.call(message);
      },
    );
  }

  Future<void> fetchServers() async {
    if (_username.isEmpty || _deviceId.isEmpty) return;

    _isFetchingServers = true;
    _serverFetchError = null;
    notifyListeners();

    try {
      _servers = await _repository.fetchVpnServers();
      _isSubscriptionExpired = false;

      // Automatically select the first server if none is selected
      if (_selectedServer == null && _servers.isNotEmpty) {
        _selectedServer = _servers.first;
      }
    } on SubscriptionExpiredException catch (e) {
      await _handleSubscriptionExpired(e.message);
    } on ApiException catch (e) {
      onErrorMessage?.call(e.message);
    } catch (e) {
      debugPrint('Unexpected fetchServers error: $e');
      onErrorMessage?.call('Something went wrong. Please try again.');
    } finally {
      _isFetchingServers = false;
      notifyListeners();
    }
  }

  /// Marks the subscription as expired and wipes the server list (memory and
  /// cache) so the app falls back to the activation screen. The active VPN
  /// connection, if any, is intentionally left untouched.
  Future<void> _handleSubscriptionExpired(String message) async {
    _isSubscriptionExpired = true;
    _servers = [];
    _selectedServer = null;
    onErrorMessage?.call(message);
    await _repository.clearServers();
  }

  Future<void> saveUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _repository.saveUsername(trimmed);
    _username = trimmed;
    notifyListeners();
    await fetchServers();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectServer(VpnServer server) {
    _useCustomConfig = false;
    _selectedServer = server;
    notifyListeners();
  }

  /// Adds or removes [server] from the persisted bookmarks. The full server
  /// record is stored so the bookmark survives future server refetches.
  Future<void> toggleBookmark(VpnServer server) async {
    final index = _bookmarkedServers.indexWhere(
      (b) => b.endpoint == server.endpoint,
    );
    if (index != -1) {
      _bookmarkedServers.removeAt(index);
    } else {
      _bookmarkedServers.add(server);
    }
    notifyListeners();
    await _repository.saveBookmarkedServers(_bookmarkedServers);
  }

  void setUseCustomConfig(bool use) {
    _useCustomConfig = use;
    notifyListeners();
  }

  List<VpnServer> getFilteredServers() {
    if (_searchQuery.trim().isEmpty) {
      return _servers;
    }
    final q = _searchQuery.toLowerCase();
    return _servers.where((server) {
      return server.country.toLowerCase().contains(q) ||
          server.hostname.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> toggleVpnConnection() async {
    if (_connectionStatus == SSTPConnectionStatusKeys.connected ||
        _connectionStatus == SSTPConnectionStatusKeys.connecting) {
      // Disconnect
      try {
        await _tunnel.disconnect();
      } catch (e) {
        onErrorMessage?.call('Error disconnecting: $e');
      }
    } else {
      // Connect
      if (!_useCustomConfig && _selectedServer == null) {
        onErrorMessage?.call('Please select a VPN server first.');
        return;
      }

      final String targetHost = _useCustomConfig
          ? customHostController.text.trim()
          : _selectedServer!.ip;
      final int targetPort = _useCustomConfig
          ? (int.tryParse(customPortController.text) ?? 443)
          : _selectedServer!.port;
      final String targetUsername = _useCustomConfig
          ? customUsernameController.text.trim()
          : 'vpn';
      final String targetPassword = _useCustomConfig
          ? customPasswordController.text
          : 'vpn';

      if (targetHost.isEmpty) {
        onErrorMessage?.call('Host address cannot be empty.');
        return;
      }

      try {
        _connectionStatus = SSTPConnectionStatusKeys.connecting;
        notifyListeners();

        // System VPN consent on mobile; a no-op on desktop, where privilege is
        // granted outside the app.
        await _tunnel.requestPermission();

        await _tunnel.connect(
          VpnTunnelConfig(
            host: targetHost,
            port: targetPort,
            username: targetUsername,
            password: targetPassword,
            label: _useCustomConfig ? targetHost : _selectedServer!.hostname,
          ),
        );
      } catch (e) {
        _connectionStatus = SSTPConnectionStatusKeys.disconnected;
        notifyListeners();
        onErrorMessage?.call('Error starting VPN: $e');
      }
    }
  }

  Future<int?> _pingServer(VpnServer server) =>
      _pingService.ping(server, timeoutMs: _pingTimeoutMs);

  Future<void> sortServersByPing() async {
    // Pinging while the tunnel is up is meaningless — the ping would travel
    // through the VPN, not measure real reachability from the user's network.
    if (isConnected) {
      onErrorMessage?.call(
        'You can\'t ping servers while connected. Disconnect the VPN first.',
      );
      return;
    }

    if (_isPinging || _servers.isEmpty) return;

    // Snapshot the current servers, then clear the visible list so the UI
    // resets and the freshly pinged results appear as they come in.
    final sourceServers = List<VpnServer>.from(_servers);
    _servers = [];

    _isPinging = true;
    _pingProgress = 0;
    _pingTotal = sourceServers.length;
    notifyListeners();

    final batchSize = _pingBatchSize;

    for (int i = 0; i < sourceServers.length; i += batchSize) {
      final batch = sourceServers.skip(i).take(batchSize);

      await Future.wait(
        batch.map((server) async {
          final ping = await _pingServer(server);
          // Publish each result immediately so the list and the progress
          // counter update in real time as servers are probed.
          _servers.add(ping != null ? server.copyWith(ping: ping) : server);
          _pingProgress++;
          notifyListeners();
        }),
      );
    }

    _servers.sort((a, b) {
      final pa = a.ping ?? 999999;
      final pb = b.ping ?? 999999;
      return pa.compareTo(pb);
    });

    _isPinging = false;
    notifyListeners();

    // Save servers with ping times to preferences
    await _repository.saveServersWithPing(_servers);

    // _showSnackBar("Servers sorted by latency.");
  }

  /// Pings only the bookmarked servers, updating their latency in place (the
  /// list order is left untouched so bookmarks stay put while probing).
  Future<void> pingBookmarkedServers() async {
    if (isConnected) {
      onErrorMessage?.call(
        'You can\'t ping servers while connected. Disconnect the VPN first.',
      );
      return;
    }

    if (_isPinging) return;

    final targets = List<VpnServer>.from(_bookmarkedServers);
    if (targets.isEmpty) return;

    _isPinging = true;
    _pingProgress = 0;
    _pingTotal = targets.length;
    notifyListeners();

    final batchSize = _pingBatchSize;

    for (int i = 0; i < targets.length; i += batchSize) {
      final batch = targets.skip(i).take(batchSize);

      await Future.wait(
        batch.map((server) async {
          final ping = await _pingServer(server);
          if (ping != null) {
            _updatePing(_bookmarkedServers, server.endpoint, ping);
            _updatePing(_servers, server.endpoint, ping);
          }
          _pingProgress++;
          notifyListeners();
        }),
      );
    }

    _isPinging = false;
    notifyListeners();

    await _repository.saveBookmarkedServers(_bookmarkedServers);
    await _repository.saveServersWithPing(_servers);
  }

  /// Updates the ping of the server matching [endpoint] within [list], if any.
  void _updatePing(List<VpnServer> list, String endpoint, int ping) {
    final index = list.indexWhere((s) => s.endpoint == endpoint);
    if (index != -1) {
      list[index] = list[index].copyWith(ping: ping);
    }
  }

  /// Updates the per-server ping timeout (in seconds) in memory. Call
  /// [persistPingSettings] to save (e.g. when the slider is released).
  void setPingTimeoutSeconds(double seconds) {
    _pingTimeoutMs = (seconds * 1000).round();
    notifyListeners();
  }

  /// Updates the number of servers pinged concurrently, in memory.
  void setPingBatchSize(int size) {
    _pingBatchSize = size < 1 ? 1 : size;
    notifyListeners();
  }

  Future<void> persistPingSettings() {
    return _repository.savePingSettings(
      timeoutMs: _pingTimeoutMs,
      batchSize: _pingBatchSize,
    );
  }

  void _loadCachedServers() {
    _repository.loadServersWithPing().then((cachedServers) {
      if (cachedServers.isNotEmpty && _servers.isEmpty) {
        _servers = cachedServers;
        notifyListeners();
      }
    });
  }

  /// Imports an activation code. Returns `true` on success, or `false` if the
  /// code is malformed/invalid (in which case the user is warned and no state
  /// is changed).
  Future<bool> importActivationCode(String base64) async {
    try {
      await _repository.importActivationCode(base64.trim());
    } catch (e) {
      debugPrint('Failed to import activation code: $e');
      onErrorMessage?.call(
        'Invalid activation code. Please check the code and try again.',
      );
      return false;
    }

    _isSubscriptionExpired = false;
    _username = await _repository.getUsername();

    _servers = _repository.cachedServers;

    if (_selectedServer == null && _servers.isNotEmpty) {
      _selectedServer = _servers.first;
    }

    notifyListeners();

    await sortServersByPing();
    return true;
  }

  bool _isStartingTrial = false;
  bool get isStartingTrial => _isStartingTrial;

  /// Starts the one-time free trial (foreign variant). On success the backend
  /// returns an activation blob that unlocks access for the trial period.
  Future<bool> startFreeTrial() async {
    if (_isStartingTrial) return false;

    _isStartingTrial = true;
    notifyListeners();

    try {
      await _repository.startFreeTrial();
    } on ApiException catch (e) {
      onErrorMessage?.call(e.message);
      return false;
    } catch (e) {
      debugPrint('Trial start failed: $e');
      onErrorMessage?.call('Could not start your free trial. Please try again.');
      return false;
    } finally {
      _isStartingTrial = false;
      notifyListeners();
    }

    _isSubscriptionExpired = false;
    _username = await _repository.getUsername();
    _servers = _repository.cachedServers;
    if (_selectedServer == null && _servers.isNotEmpty) {
      _selectedServer = _servers.first;
    }
    notifyListeners();

    await sortServersByPing();
    return true;
  }

  bool _isSubmittingSubscription = false;
  bool get isSubmittingSubscription => _isSubmittingSubscription;

  /// Submits a crypto payment for on-chain verification (foreign variant).
  /// On success the backend returns an activation blob that unlocks access
  /// exactly like an activation code.
  Future<bool> submitSubscription({
    required String network,
    required String txHash,
  }) async {
    if (_isSubmittingSubscription) return false;

    _isSubmittingSubscription = true;
    notifyListeners();

    try {
      await _repository.subscribeWithCrypto(network: network, txHash: txHash);
    } on ApiException catch (e) {
      onErrorMessage?.call(e.message);
      return false;
    } catch (e) {
      debugPrint('Subscription failed: $e');
      onErrorMessage?.call('Could not verify your payment. Please try again.');
      return false;
    } finally {
      _isSubmittingSubscription = false;
      notifyListeners();
    }

    _isSubscriptionExpired = false;
    _username = await _repository.getUsername();
    _servers = _repository.cachedServers;
    if (_selectedServer == null && _servers.isNotEmpty) {
      _selectedServer = _servers.first;
    }
    notifyListeners();

    await sortServersByPing();
    return true;
  }

  /// Whether a server download is due. True when servers have never been
  /// fetched or the last successful fetch was at least a day ago.
  bool get _isServerRefreshDue {
    final last = _repository.lastFetchTime;
    if (last == null) return true;
    return DateTime.now().difference(last) >= const Duration(days: 1);
  }

  Future<bool> _refreshServers() async {
    try {
      _servers = await _repository.fetchServersAndMerge();
      _isSubscriptionExpired = false;
      notifyListeners();
      return true;
    } on SubscriptionExpiredException catch (e) {
      await _handleSubscriptionExpired(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      return false;
    }
  }
}

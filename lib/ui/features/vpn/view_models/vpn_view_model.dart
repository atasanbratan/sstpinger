import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sstp_flutter/sstp_flutter.dart';
import 'package:sstp_flutter/server.dart';
import 'package:sstp_flutter/android_configuration_sstp.dart';
import 'package:sstp_flutter/ios_configuration_sstp.dart';
import 'package:sstp_flutter/ssl_versions.dart';
import 'package:sstp_flutter/traffic.dart';

import '../../../../data/models/vpn_server.dart';
import '../../../../data/repositories/vpn_repository.dart';

class SSTPConnectionStatusKeys {
  static const String CONNECTED = 'Connected';
  static const String CONNECTING = 'Connecting';
  static const String DISCONNECTED = 'Disconnected';
  static const String DISCONNECTING = 'Disconnecting';
}

class VpnViewModel extends ChangeNotifier {
  final VpnRepository _repository;
  final SstpFlutter _sstpFlutter = SstpFlutter();

  // Callbacks
  void Function(String)? onErrorMessage;

  // State fields
  bool _isPinging = false;
  bool get isPinging => _isPinging;

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

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _connectionStatus = SSTPConnectionStatusKeys.DISCONNECTED;
  String get connectionStatus => _connectionStatus;

  ConnectionTraffic? _traffic;
  ConnectionTraffic? get traffic => _traffic;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  VpnServer? _selectedServer;
  VpnServer? get selectedServer => _selectedServer;

  bool _useCustomConfig = false;
  bool get useCustomConfig => _useCustomConfig;

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

  VpnViewModel({required this._repository}) {
    _init();
  }

  @override
  void dispose() {
    customHostController.dispose();
    customPortController.dispose();
    customUsernameController.dispose();
    customPasswordController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _username = await _repository.getUsername();
    _deviceId = await _repository.getOrCreateDeviceId();
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
      _connectionStatus = await _sstpFlutter.checkLastConnectionStatus();
    } catch (e) {
      debugPrint('Error checking last connection status: $e');
    }
  }

  void _setupSstpListener() {
    _sstpFlutter.onResult(
      onConnectedResult: (ConnectionTraffic traffic, Duration duration) {
        _connectionStatus = SSTPConnectionStatusKeys.CONNECTED;
        _traffic = traffic;
        _duration = duration;
        notifyListeners();
      },
      onConnectingResult: () {
        _connectionStatus = SSTPConnectionStatusKeys.CONNECTING;
        notifyListeners();
      },
      onDisconnectedResult: () {
        _connectionStatus = SSTPConnectionStatusKeys.DISCONNECTED;
        _traffic = null;
        _duration = Duration.zero;
        notifyListeners();
      },
      onError: () {
        _connectionStatus = SSTPConnectionStatusKeys.DISCONNECTED;
        _traffic = null;
        _duration = Duration.zero;
        notifyListeners();
        onErrorMessage?.call(
          'Connection failed. Please choose another server.',
        );
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

      // Automatically select the first server if none is selected
      if (_selectedServer == null && _servers.isNotEmpty) {
        _selectedServer = _servers.first;
      }
    } catch (e) {
      _serverFetchError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isFetchingServers = false;
      notifyListeners();
    }
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
          server.hostname.toLowerCase().contains(q) ||
          server.ip.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> toggleVpnConnection() async {
    if (_connectionStatus == SSTPConnectionStatusKeys.CONNECTED ||
        _connectionStatus == SSTPConnectionStatusKeys.CONNECTING) {
      // Disconnect
      try {
        await _sstpFlutter.disconnect();
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
        _connectionStatus = SSTPConnectionStatusKeys.CONNECTING;
        notifyListeners();

        // Request VPN Permission from System
        await _sstpFlutter.takePermission();

        // Build server config
        final serverConfig = SSTPServer(
          host: targetHost,
          port: targetPort,
          username: targetUsername,
          password: targetPassword,
          androidConfiguration: SSTPAndroidConfiguration(
            verifyHostName: false,
            verifySSLCert: false,
            useTrustedCert: false,
            sslVersion: SSLVersions.TLsv1_3,
            showDisconnectOnNotification: true,
            notificationText: _useCustomConfig
                ? 'Connected to $targetHost'
                : 'Connected to ${_selectedServer!.hostname}',
          ),
          iosConfiguration: SSTPIOSConfiguration(
            enablePAP: true,
            enableMSCHAP2: true,
            enableTLS: false,
            enableCHAP: false,
          ),
        );

        // Save server configuration
        await _sstpFlutter.saveServerData(server: serverConfig);

        // Initiate VPN connection
        await _sstpFlutter.connectVpn();
      } catch (e) {
        _connectionStatus = SSTPConnectionStatusKeys.DISCONNECTED;
        notifyListeners();
        onErrorMessage?.call('Error starting VPN: $e');
      }
    }
  }

  Future<int?> _pingServer(VpnServer server) async {
    final stopwatch = Stopwatch()..start();

    try {
      final socket = await Socket.connect(
        server.ip,
        server.port,
        timeout: const Duration(seconds: 3),
      );

      stopwatch.stop();
      await socket.close();

      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  Future<void> sortServersByPing() async {
    if (_isPinging || _servers.isEmpty) return;

    _isPinging = true;
    notifyListeners();

    const batchSize = 25;

    for (int i = 0; i < _servers.length; i += batchSize) {
      final batch = _servers.skip(i).take(batchSize);

      await Future.wait(
        batch.map((server) async {
          server.ping = await _pingServer(server);
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

  void _loadCachedServers() {
    _repository.loadServersWithPing().then((cachedServers) {
      if (cachedServers.isNotEmpty && _servers.isEmpty) {
        _servers = cachedServers;
        notifyListeners();
      }
    });
  }
}

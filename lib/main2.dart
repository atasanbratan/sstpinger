import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:advertising_id/advertising_id.dart';
import 'package:sstp_flutter/sstp_flutter.dart';
import 'package:sstp_flutter/server.dart';
import 'package:sstp_flutter/android_configuration_sstp.dart';
import 'package:sstp_flutter/ios_configuration_sstp.dart';
import 'package:sstp_flutter/ssl_versions.dart';
import 'package:sstp_flutter/traffic.dart';

class SSTPConnectionStatusKeys {
  static const String CONNECTED = 'Connected';
  static const String CONNECTING = 'Connecting';
  static const String DISCONNECTED = 'Disconnected';
  static const String DISCONNECTING = 'Disconnecting';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SstpVpnApp());
}

class SstpVpnApp extends StatelessWidget {
  const SstpVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSTP Shield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        cardColor: const Color(0xFF151D30),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(fontFamily: 'Outfit', color: Colors.white),
          bodyMedium: TextStyle(fontFamily: 'Outfit', color: Colors.white70),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2FF),
          secondary: Color(0xFF9D4EDD),
          surface: Color(0xFF151D30),
        ),
      ),
      home: const MainVpnScreen(),
    );
  }
}

class VpnServer {
  final int id;
  final String hostname;
  final String ip;
  final int port;
  final String key;
  final int sessions;
  final String info;
  final String info2;
  final String country;
  final String countryShort;
  final String locationName;
  int? ping;

  VpnServer({
    required this.id,
    required this.hostname,
    required this.ip,
    required this.port,
    required this.key,
    required this.sessions,
    required this.info,
    required this.info2,
    required this.country,
    required this.countryShort,
    required this.locationName,
  });

  factory VpnServer.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    return VpnServer(
      id: json['id'] as int? ?? 0,
      hostname: json['hostname'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      port: json['port'] as int? ?? 443,
      key: json['key'] as String? ?? '',
      sessions: json['sessions'] as int? ?? 0,
      info: json['info'] as String? ?? '',
      info2: json['info2'] as String? ?? '',
      country: loc['country'] as String? ?? '',
      countryShort: loc['short'] as String? ?? '',
      locationName: loc['name'] as String? ?? '',
    );
  }
}

class MainVpnScreen extends StatefulWidget {
  const MainVpnScreen({super.key});

  @override
  State<MainVpnScreen> createState() => _MainVpnScreenState();
}

class _MainVpnScreenState extends State<MainVpnScreen> {
  final SstpFlutter _sstpFlutter = SstpFlutter();

  // App states
  bool _initialized = false;
  String _username = '';
  String _deviceId = '';
  List<VpnServer> _servers = [];
  bool _isFetchingServers = false;
  String? _serverFetchError;

  // Search filter
  String _searchQuery = '';

  // Connection states
  String _connectionStatus = SSTPConnectionStatusKeys.DISCONNECTED;
  ConnectionTraffic? _traffic;
  Duration _duration = Duration.zero;
  VpnServer? _selectedServer;

  // Custom server config overrides (Advanced options)
  bool _useCustomConfig = false;
  final TextEditingController _customHostController = TextEditingController();
  final TextEditingController _customPortController = TextEditingController(
    text: '443',
  );
  final TextEditingController _customUsernameController = TextEditingController(
    text: 'vpn',
  );
  final TextEditingController _customPasswordController = TextEditingController(
    text: 'vpn',
  );

  bool _isPinging = false;

  Future<void> _sortServersByPing() async {
    if (_isPinging || _servers.isEmpty) return;

    setState(() {
      _isPinging = true;
    });

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

    setState(() {
      _isPinging = false;
    });

    _showSnackBar("Servers sorted by latency.");
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

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  @override
  void dispose() {
    _customHostController.dispose();
    _customPortController.dispose();
    _customUsernameController.dispose();
    _customPasswordController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    await _loadPreferencesAndId();
    await _checkLastStatus();
    _setupSstpListener();
    if (_username.isNotEmpty) {
      _fetchServers();
    }
    setState(() {
      _initialized = true;
    });
  }

  Future<void> _loadPreferencesAndId() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username') ?? '';

    // Get Device ID (Advertising ID or Fallback UUID)
    String? cachedId = prefs.getString('device_id');
    if (cachedId != null && cachedId.isNotEmpty) {
      _deviceId = cachedId;
    } else {
      String id = await _getOrCreateDeviceId(prefs);
      _deviceId = id;
    }
    setState(() {});
  }

  Future<String> _getOrCreateDeviceId(SharedPreferences prefs) async {
    // Try to get Google Ads ID (Advertising ID)
    try {
      String? adId = await AdvertisingId.id(true);
      if (adId != null &&
          adId.isNotEmpty &&
          adId != "00000000-0000-0000-0000-000000000000") {
        await prefs.setString('device_id', adId);
        return adId;
      }
    } catch (e) {
      debugPrint('Failed to get Advertising ID: $e');
    }

    // Fallback to random UUID v4
    final random = Random();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Set version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Set variant RFC4122

    final hexList = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .toList();
    final uuid =
        '${hexList.sublist(0, 4).join()}-${hexList.sublist(4, 6).join()}-${hexList.sublist(6, 8).join()}-${hexList.sublist(8, 10).join()}-${hexList.sublist(10, 16).join()}';

    await prefs.setString('device_id', uuid);
    return uuid;
  }

  Future<void> _checkLastStatus() async {
    try {
      final status = await _sstpFlutter.checkLastConnectionStatus();
      setState(() {
        _connectionStatus = status;
      });
    } catch (e) {
      debugPrint('Error checking last connection status: $e');
    }
  }

  void _setupSstpListener() {
    _sstpFlutter.onResult(
      onConnectedResult: (ConnectionTraffic traffic, Duration duration) {
        setState(() {
          _connectionStatus = SSTPConnectionStatusKeys.CONNECTED;
          _traffic = traffic;
          _duration = duration;
        });
      },
      onConnectingResult: () {
        setState(() {
          _connectionStatus = SSTPConnectionStatusKeys.CONNECTING;
        });
      },
      onDisconnectedResult: () {
        setState(() {
          _connectionStatus = SSTPConnectionStatusKeys.DISCONNECTED;
          _traffic = null;
          _duration = Duration.zero;
        });
      },
      onError: () {
        setState(() {
          _connectionStatus = SSTPConnectionStatusKeys.DISCONNECTED;
          _traffic = null;
          _duration = Duration.zero;
        });
        _showSnackBar('Connection failed. Please choose another server.');
      },
    );
  }

  Future<void> _fetchServers() async {
    if (_username.isEmpty || _deviceId.isEmpty) return;

    setState(() {
      _isFetchingServers = true;
      _serverFetchError = null;
    });

    // 1. Initialize Dio
    final dio = Dio();

    final url =
        'https://script.google.com/macros/s/AKfycbyqKggC-QqxUAoc-u_8uut3gbHoFMXUr5-N7gQlIp53Ga6juJ8g12jJFvEiDgp9-I2c/exec';

    // 2. Prepare your payload
    final Map<String, dynamic> payload = {
      'deviceId': _deviceId,
      'username': _username,
    };

    try {
      // final response = await http.post(
      //   Uri.parse(
      //     'https://script.google.com/macros/s/AKfycbyqKggC-QqxUAoc-u_8uut3gbHoFMXUr5-N7gQlIp53Ga6juJ8g12jJFvEiDgp9-I2c/exec',
      //   ),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({'deviceId': _deviceId, 'username': _username}),
      // );

      // 3. Make the POST request with redirect handling options
      Response<String> response = await dio.post(
        url,
        queryParameters: payload,
        data: payload,
        options: Options(
          contentType: Headers.jsonContentType,
          followRedirects: false, // We will manually handle the redirect hop
          validateStatus: (status) => status! < 500,
        ),
      );

      String? redirectUrl;

      // 2. Check if the redirect URL is in the HTTP Headers
      if (response.headers['location'] != null &&
          response.headers['location']!.isNotEmpty) {
        redirectUrl = response.headers['location']!.first;
      }
      // 3. Fallback: Extract the URL from the HTML string using regex if headers are masked
      else if (response.data != null &&
          response.data.toString().contains('href="')) {
        final dataStr = response.data.toString();
        final regExp = RegExp(r'href="([^"]+)"');
        final match = regExp.firstMatch(dataStr);
        if (match != null) {
          // Replace &amp; with & from the HTML text link
          redirectUrl = match.group(1)?.replaceAll('&amp;', '&');
        }
      }

      // 4. Perform the secondary request to complete the handshake
      if (redirectUrl != null) {
        print('Following redirect to: $redirectUrl');

        // Google demands a GET request to the redirected 'echo' endpoint
        final finalResponse = await dio.get<String>(redirectUrl);

        response = finalResponse;

        print('Final Status Code: ${finalResponse.statusCode}');
        print('Final Output from Apps Script: ${finalResponse.data}');
      } else {
        print(
          'Failed to locate redirect URL. Direct response: ${response.data}',
        );
      }

      // 4. Handle your response
      print('Status Code: ${response.statusCode}');
      print(
        'Response Data: ${response.data}',
      ); // Contains the text/JSON returned from Apps Script

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.data ?? "");
        if (decoded['success'] == true) {
          final list = decoded['data'] as List<dynamic>? ?? [];
          setState(() {
            _servers = list.map((item) => VpnServer.fromJson(item)).toList();
            _isFetchingServers = false;

            // Automatically select the first server if none is selected
            if (_selectedServer == null && _servers.isNotEmpty) {
              _selectedServer = _servers.first;
            }
          });
        } else {
          setState(() {
            _serverFetchError =
                decoded['error'] ?? 'API Error: success flag is false';
            _isFetchingServers = false;
          });
        }
      } else {
        setState(() {
          _serverFetchError =
              'API responded with status: ${response.statusCode}';
          _isFetchingServers = false;
        });
      }
    } on DioException catch (e) {
      print('Dio Error: ${e.toString()}');

      if (e.response != null) {
        print('Error Data: ${e.response?.data}');
      }
    } catch (e) {
      setState(() {
        _serverFetchError = 'Network error: $e';
        _isFetchingServers = false;
      });
    }
  }

  Future<void> _saveUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', trimmed);
    setState(() {
      _username = trimmed;
    });
    _fetchServers();
  }

  Future<void> _toggleVpnConnection() async {
    if (_connectionStatus == SSTPConnectionStatusKeys.CONNECTED ||
        _connectionStatus == SSTPConnectionStatusKeys.CONNECTING) {
      // Disconnect
      try {
        await _sstpFlutter.disconnect();
      } catch (e) {
        _showSnackBar('Error disconnecting: $e');
      }
    } else {
      // Connect
      if (!_useCustomConfig && _selectedServer == null) {
        _showSnackBar('Please select a VPN server first.');
        return;
      }

      final String targetHost = _useCustomConfig
          ? _customHostController.text.trim()
          : _selectedServer!.ip;
      final int targetPort = _useCustomConfig
          ? (int.tryParse(_customPortController.text) ?? 443)
          : _selectedServer!.port;
      final String targetUsername = _useCustomConfig
          ? _customUsernameController.text.trim()
          : 'vpn';
      final String targetPassword = _useCustomConfig
          ? _customPasswordController.text
          : 'vpn';

      if (targetHost.isEmpty) {
        _showSnackBar('Host address cannot be empty.');
        return;
      }

      try {
        setState(() {
          _connectionStatus = SSTPConnectionStatusKeys.CONNECTING;
        });

        // Request VPN Permission from System
        await _sstpFlutter.takePermission();

        // Build server config
        final server = SSTPServer(
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
        await _sstpFlutter.saveServerData(server: server);

        // Initiate VPN connection
        await _sstpFlutter.connectVpn();
      } catch (e) {
        setState(() {
          _connectionStatus = SSTPConnectionStatusKeys.DISCONNECTED;
        });
        _showSnackBar('Error starting VPN: $e');
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Country Flag Generator helper
  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '🌐';
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  // Formatting units
  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var i = (log(bytesPerSecond) / log(1024)).floor();
    i = i.clamp(0, suffixes.length - 1);
    return '${(bytesPerSecond / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatTraffic(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    i = i.clamp(0, suffixes.length - 1);
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D2FF)),
        ),
      );
    }

    // Username setup window/dialog
    if (_username.isEmpty) {
      return _buildUsernameScreen();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              color: Color(0xFF00D2FF),
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'SSTP SHIELD',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(letterSpacing: 2, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isPinging
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed, color: Colors.white70),
            tooltip: "Sort by Ping",
            onPressed: _isPinging ? null : _sortServersByPing,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh server list',
            onPressed: _isFetchingServers ? null : _fetchServers,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Settings / Profile',
            onPressed: _showProfileAndSettingsModal,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00D2FF),
          onRefresh: () =>
              Future.delayed(const Duration(seconds: 1)), // _fetchServers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),

                  // Active Connection details
                  _buildConnectionStatusWidget(),

                  const SizedBox(height: 25),

                  // Selected Server & Toggle panel
                  _buildConnectionControlCard(),

                  const SizedBox(height: 20),

                  // Server List Search & Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'VPN SERVERS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.grey[400],
                        ),
                      ),
                      Text(
                        '${_getFilteredServers().length} Available',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search TextField
                  _buildSearchField(),

                  const SizedBox(height: 12),

                  // Server List
                  _buildServerListWidget(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameScreen() {
    final TextEditingController controller = TextEditingController();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1222), Color(0xFF070B14)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.vpn_lock_rounded,
                  size: 80,
                  color: Color(0xFF00D2FF),
                ),
                const SizedBox(height: 20),
                const Text(
                  'SSTP SHIELD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Secure Gateway to SSTP VPN Nodes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 48),

                // Welcome card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: const Color(0xFF161F34),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Let\'s Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please enter a username to fetch the latest VPN servers from the registry.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter username',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(
                              Icons.person,
                              color: Color(0xFF00D2FF),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0B101E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _saveUsername(val);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            if (controller.text.trim().isNotEmpty) {
                              _saveUsername(controller.text);
                            } else {
                              _showSnackBar('Username cannot be empty.');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D2FF),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Center(
                            child: Text(
                              'CONTINUE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusWidget() {
    final bool isConnected =
        _connectionStatus == SSTPConnectionStatusKeys.CONNECTED;
    final bool isConnecting =
        _connectionStatus == SSTPConnectionStatusKeys.CONNECTING;

    Color statusColor = Colors.grey;
    String statusText = 'DISCONNECTED';

    if (isConnected) {
      statusColor = const Color(0xFF10B981); // Vibrant Emerald Green
      statusText = 'CONNECTED';
    } else if (isConnecting) {
      statusColor = const Color(0xFFF59E0B); // Golden Amber
      statusText = 'CONNECTING...';
    }

    return Column(
      children: [
        // Power button glow animation frame
        GestureDetector(
          onTap: _toggleVpnConnection,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.06),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
              ),
              // Inner pulse ring
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.15),
                      blurRadius: isConnecting ? 25 : 15,
                      spreadRadius: isConnecting ? 5 : 2,
                    ),
                  ],
                ),
              ),
              // Button core
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1F293D),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.8),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 48,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isConnected ? _formatDuration(_duration) : '00:00:00',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionControlCard() {
    final bool isConnected =
        _connectionStatus == SSTPConnectionStatusKeys.CONNECTED;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF151D30),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            // Selected node details
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _useCustomConfig
                        ? '🔧'
                        : (_selectedServer != null
                              ? _getFlagEmoji(_selectedServer!.countryShort)
                              : '🌐'),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _useCustomConfig
                            ? 'Custom Node Configuration'
                            : (_selectedServer != null
                                  ? _selectedServer!.country.toUpperCase()
                                  : 'No Node Selected'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _useCustomConfig
                            ? '${_customHostController.text}:${_customPortController.text}'
                            : (_selectedServer != null
                                  ? _selectedServer!.hostname
                                  : 'Select from server list below'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _useCustomConfig
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _useCustomConfig ? 'CUSTOM' : 'API NODES',
                    style: TextStyle(
                      fontSize: 9,
                      color: _useCustomConfig
                          ? Colors.orangeAccent
                          : const Color(0xFF00D2FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Connection speeds (Download/Upload) if connected
            if (isConnected) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(color: Colors.white10),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSpeedIndicator(
                    label: 'DOWNLOAD SPEED',
                    speed: _traffic != null
                        ? _formatSpeed(_traffic!.downloadTraffic ?? 0)
                        : '0.0 KB/s',
                    total: _traffic != null
                        ? _formatTraffic(_traffic!.totalDownloadTraffic ?? 0)
                        : '0.0 MB',
                    icon: Icons.arrow_downward_rounded,
                    color: const Color(0xFF00D2FF),
                  ),
                  Container(height: 40, width: 1, color: Colors.white10),
                  _buildSpeedIndicator(
                    label: 'UPLOAD SPEED',
                    speed: _traffic != null
                        ? _formatSpeed(_traffic!.uploadTraffic ?? 0)
                        : '0.0 KB/s',
                    total: _traffic != null
                        ? _formatTraffic(_traffic!.totalUploadTraffic ?? 0)
                        : '0.0 MB',
                    icon: Icons.arrow_upward_rounded,
                    color: const Color(0xFF9D4EDD),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedIndicator({
    required String label,
    required String speed,
    required String total,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 1,
                color: Colors.grey[400],
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              speed,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Total: $total',
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search by country or hostname...',
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF151D30),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
    );
  }

  List<VpnServer> _getFilteredServers() {
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

  Widget _buildServerListWidget() {
    if (_isFetchingServers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D2FF)),
        ),
      );
    }

    if (_serverFetchError != null) {
      return Card(
        color: const Color(0xFF2D161F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'Fetch Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _serverFetchError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _fetchServers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('RETRY'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _promptEditUsername,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('CHANGE USERNAME'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _getFilteredServers();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Text(
            'No servers match your search filter.',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final server = filtered[index];
        final bool isSelected =
            !_useCustomConfig && _selectedServer?.id == server.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: InkWell(
            onTap: () {
              setState(() {
                _useCustomConfig = false;
                _selectedServer = server;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E2D4A)
                    : const Color(0xFF151D30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00D2FF).withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Country Flag
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getFlagEmoji(server.countryShort),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Server details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.country.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          server.hostname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${server.ip}:${server.port}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.cyan[200],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sessions: ${server.sessions}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Checked symbol
                  if (server.ping != null)
                    Text(
                      "${server.ping} ms",
                      style: TextStyle(
                        color: server.ping! < 80
                            ? Colors.green
                            : server.ping! < 150
                            ? Colors.orange
                            : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      "--",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),

                  const SizedBox(width: 8),

                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF00D2FF),
                      size: 22,
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white38,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProfileAndSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SETTINGS & PROFILE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Profile details card
                    const Text(
                      'USER PROFILE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Color(0xFF00D2FF),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Username',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white38,
                                        ),
                                      ),
                                      Text(
                                        _username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _promptEditUsername();
                                  },
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_android,
                                  color: Color(0xFF9D4EDD),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Device Advertising ID',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white38,
                                        ),
                                      ),
                                      Text(
                                        _deviceId,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _deviceId),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Device ID copied to clipboard',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Advanced connection override settings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'USE CUSTOM NODE SETTINGS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white38,
                          ),
                        ),
                        Switch(
                          value: _useCustomConfig,
                          activeThumbColor: const Color(0xFF00D2FF),
                          onChanged: (val) {
                            setModalState(() {
                              _useCustomConfig = val;
                            });
                            setState(() {
                              _useCustomConfig = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_useCustomConfig) ...[
                      TextField(
                        controller: _customHostController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Host IP / Hostname',
                          labelStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF00D2FF)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customPortController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                                labelStyle: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFF00D2FF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _customUsernameController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'VPN User',
                                labelStyle: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFF00D2FF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customPasswordController,
                        obscureText: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'VPN Password',
                          labelStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF00D2FF)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _promptEditUsername() {
    final TextEditingController textController = TextEditingController(
      text: _username,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151D30),
          title: const Text(
            'Change Username',
            style: TextStyle(color: Colors.white, fontFamily: 'Outfit'),
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter new username',
              hintStyle: TextStyle(color: Colors.white38),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00D2FF)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  _saveUsername(textController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'SAVE',
                style: TextStyle(color: Color(0xFF00D2FF)),
              ),
            ),
          ],
        );
      },
    );
  }
}

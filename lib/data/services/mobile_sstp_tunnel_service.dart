import 'package:sstp_flutter/android_configuration_sstp.dart';
import 'package:sstp_flutter/ios_configuration_sstp.dart';
import 'package:sstp_flutter/server.dart';
import 'package:sstp_flutter/ssl_versions.dart';
import 'package:sstp_flutter/sstp_flutter.dart';
import 'package:sstp_flutter/traffic.dart';

import '../models/tunnel_traffic.dart';
import 'vpn_tunnel_service.dart';

/// Android / iOS tunnel, via the `sstp_flutter` plugin.
///
/// This is the app's original connection logic, moved out of `VpnViewModel`
/// unchanged. It is the only place `sstp_flutter` is allowed to be imported.
class MobileSstpTunnelService implements VpnTunnelService {
  final SstpFlutter _sstp = SstpFlutter();

  @override
  Future<String> lastConnectionStatus() => _sstp.checkLastConnectionStatus();

  @override
  void onResult({
    required void Function(TunnelTraffic? traffic, Duration duration) onConnected,
    required void Function() onConnecting,
    required void Function() onDisconnected,
    required void Function(String message) onError,
  }) {
    _sstp.onResult(
      onConnectedResult: (ConnectionTraffic traffic, Duration duration) {
        onConnected(
          TunnelTraffic(
            downloadTraffic: traffic.downloadTraffic,
            totalDownloadTraffic: traffic.totalDownloadTraffic,
            uploadTraffic: traffic.uploadTraffic,
            totalUploadTraffic: traffic.totalUploadTraffic,
          ),
          duration,
        );
      },
      onConnectingResult: onConnecting,
      onDisconnectedResult: onDisconnected,
      // The plugin reports failure with no detail, so the message is ours.
      onError: () => onError('Connection failed. Please choose another server.'),
    );
  }

  @override
  Future<void> requestPermission() => _sstp.takePermission();

  @override
  Future<void> connect(VpnTunnelConfig config) async {
    await _sstp.saveServerData(
      server: SSTPServer(
        host: config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        androidConfiguration: SSTPAndroidConfiguration(
          verifyHostName: false,
          verifySSLCert: false,
          useTrustedCert: false,
          sslVersion: SSLVersions.TLsv1_3,
          showDisconnectOnNotification: true,
          notificationText: 'Connected to ${config.label}',
        ),
        iosConfiguration: SSTPIOSConfiguration(
          enablePAP: true,
          enableMSCHAP2: true,
          enableTLS: false,
          enableCHAP: false,
        ),
      ),
    );
    await _sstp.connectVpn();
  }

  @override
  Future<void> disconnect() => _sstp.disconnect();

  @override
  void dispose() {}
}

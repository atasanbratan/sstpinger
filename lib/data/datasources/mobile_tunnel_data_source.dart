import 'package:sstp_flutter/android_configuration_sstp.dart';
import 'package:sstp_flutter/ios_configuration_sstp.dart';
import 'package:sstp_flutter/server.dart';
import 'package:sstp_flutter/ssl_versions.dart';
import 'package:sstp_flutter/sstp_flutter.dart';
import 'package:sstp_flutter/traffic.dart';

import '../../domain/entities/tunnel_config.dart';
import '../../domain/entities/tunnel_status.dart';
import '../../domain/entities/tunnel_traffic.dart';
import 'tunnel_data_source.dart';

/// Android / iOS tunnel, via the `sstp_flutter` plugin. The only place
/// `sstp_flutter` is imported.
class MobileTunnelDataSource implements TunnelDataSource {
  final SstpFlutter _sstp = SstpFlutter();

  @override
  Future<TunnelStatus> lastStatus() async {
    final raw = await _sstp.checkLastConnectionStatus();
    return switch (raw) {
      'Connected' => TunnelStatus.connected,
      'Connecting' => TunnelStatus.connecting,
      'Disconnecting' => TunnelStatus.disconnecting,
      _ => TunnelStatus.disconnected,
    };
  }

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
  Future<void> connect(TunnelConfig config) async {
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

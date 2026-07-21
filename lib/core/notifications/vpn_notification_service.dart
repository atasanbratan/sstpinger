import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/entities/tunnel_traffic.dart';
import '../utils/formatters.dart';

/// Shows a live, ongoing "connected" notification (duration + up/down speed)
/// with a Disconnect action. Tapping Disconnect reopens the app (see the
/// showsUserInterface note on the action below) so the tap is guaranteed to
/// reach ConnectionBloc rather than tearing down the tunnel natively.
///
/// Android only for now. `sstp_flutter` (the mobile tunnel plugin) already
/// posts its own OS-mandated foreground-service notification with a working
/// Disconnect button, but its text is fixed once at connect time and is not
/// exposed to Dart for live updates — so this is a second, richer
/// notification alongside it, not a replacement.
class VpnNotificationService {
  static const _channelId = 'vpn_status';
  static const _channelName = 'VPN status';
  static const _notificationId = 7301;
  static const _disconnectActionId = 'disconnect';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Invoked when the notification's Disconnect action is tapped.
  VoidCallback? onDisconnectRequested;

  Future<void> init() async {
    if (!Platform.isAndroid) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onResponse,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Android 13+ (API 33) requires this at runtime — declaring the
    // permission in the manifest alone leaves notifications silently
    // unshown, which is why the plugin's own VPN notification and this one
    // would otherwise never appear.
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Live connection stats while the VPN is on.',
        importance: Importance.low,
      ),
    );
  }

  void _onResponse(NotificationResponse response) {
    if (response.actionId == _disconnectActionId) {
      onDisconnectRequested?.call();
    }
  }

  /// Shows or updates the ongoing notification for an active connection.
  Future<void> showConnected({
    required String label,
    required Duration duration,
    required TunnelTraffic? traffic,
  }) async {
    if (!Platform.isAndroid) return;

    final body = '${Formatters.duration(duration)}  ·  '
        '↓ ${Formatters.speed(traffic?.downloadTraffic ?? 0)}  '
        '↑ ${Formatters.speed(traffic?.uploadTraffic ?? 0)}';

    await _plugin.show(
      id: _notificationId,
      title: 'Connected to $label',
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.service,
          actions: [
            AndroidNotificationAction(
              _disconnectActionId,
              'Disconnect',
              // Actions that don't show the UI are delivered to a separate
              // background isolate that has no access to ConnectionBloc, so
              // disconnecting from there would bypass _intentionalDisconnect
              // tracking and could trigger an unwanted auto-reconnect (the
              // exact bug showDisconnectOnNotification:false works around on
              // the plugin's own notification). Showing the UI keeps the tap
              // on the main isolate's onDidReceiveNotificationResponse, so it
              // reliably reaches the bloc.
              showsUserInterface: true,
              cancelNotification: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Clears the notification once the tunnel is no longer connected.
  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await _plugin.cancel(id: _notificationId);
  }
}

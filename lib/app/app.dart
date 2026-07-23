import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/notifications/vpn_notification_service.dart';
import '../presentation/bloc/connection/connection_bloc.dart';
import '../presentation/bloc/vpn/vpn_bloc.dart';
import '../presentation/screens/main_vpn_screen.dart';
import '../presentation/theme/theme.dart';

/// Root widget for the app: onboarding (free trial, activation code, or USDT
/// subscription — all offered on one gate screen, see
/// `OnboardingScreen`/`MainVpnScreen`) through to the connected experience.
/// Owns the object graph ([AppDependencies]) and provides the two blocs above
/// [MaterialApp], so pushed routes and modal sheets can read them.
class SstpVpnApp extends StatefulWidget {
  const SstpVpnApp({super.key});

  @override
  State<SstpVpnApp> createState() => _SstpVpnAppState();
}

class _SstpVpnAppState extends State<SstpVpnApp> {
  late final AppDependencies _deps;
  late final ConnectionBloc _connectionBloc;
  final _notifications = VpnNotificationService();
  StreamSubscription<VpnConnectionState>? _notificationSub;

  @override
  void initState() {
    super.initState();
    _deps = AppDependencies.create();
    _connectionBloc = _deps.buildConnectionBloc();

    // The live-stats notification (duration/speed + Disconnect action) is
    // driven straight off the bloc's stream rather than from a widget, so it
    // keeps working even while the app is backgrounded.
    _notifications.onDisconnectRequested = () =>
        _connectionBloc.add(const DisconnectRequested());
    _notifications.init();
    _notificationSub = _connectionBloc.stream.listen(_onConnectionState);
  }

  void _onConnectionState(VpnConnectionState state) {
    if (state.isConnected) {
      _notifications.showConnected(
        label: state.label.isEmpty ? 'VPN' : state.label,
        duration: state.duration,
        traffic: state.traffic,
      );
    } else {
      _notifications.cancel();
    }
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    // Owned directly (not via BlocProvider's `create:`) so the notification
    // service can reach it without a BuildContext — that means it isn't
    // auto-closed by the provider and must be closed here.
    _connectionBloc.close();
    _deps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _connectionBloc),
        BlocProvider(create: (_) => _deps.buildVpnBloc()..add(const VpnStarted())),
      ],
      child: MaterialApp(
        title: 'SSTP Shield',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainVpnScreen(),
      ),
    );
  }
}

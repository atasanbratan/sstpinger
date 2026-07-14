import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../presentation/bloc/vpn/vpn_bloc.dart';
import '../presentation/screens/main_vpn_screen.dart';
import '../presentation/theme/theme.dart';
import 'app_variant.dart';

/// Root widget for the VPN-facing variants (local + foreign).
///
/// Both share the exact same connected experience; only the onboarding gate
/// differs (activation code vs. crypto subscription), which is selected by
/// [variant] and resolved inside [MainVpnScreen]. Owns the object graph
/// ([AppDependencies]) and provides the two blocs above [MaterialApp], so pushed
/// routes and modal sheets can read them.
class SstpVpnApp extends StatefulWidget {
  final AppVariant variant;

  const SstpVpnApp({super.key, required this.variant});

  @override
  State<SstpVpnApp> createState() => _SstpVpnAppState();
}

class _SstpVpnAppState extends State<SstpVpnApp> {
  late final AppDependencies _deps;

  @override
  void initState() {
    super.initState();
    _deps = AppDependencies.create();
  }

  @override
  void dispose() {
    _deps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => _deps.buildConnectionBloc()),
        BlocProvider(create: (_) => _deps.buildVpnBloc()..add(const VpnStarted())),
      ],
      child: MaterialApp(
        title: 'SSTP Shield',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: MainVpnScreen(variant: widget.variant),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/repositories/vpn_repository.dart';
import '../ui/core/theme.dart';
import '../ui/features/vpn/view_models/vpn_view_model.dart';
import '../ui/features/vpn/views/main_vpn_screen.dart';
import 'app_variant.dart';

/// Root widget for the VPN-facing variants (local + foreign).
///
/// Both share the exact same connected experience; only the onboarding gate
/// differs (activation code vs. crypto subscription), which is selected by
/// [variant] and resolved inside [MainVpnScreen].
class SstpVpnApp extends StatefulWidget {
  final AppVariant variant;

  const SstpVpnApp({super.key, required this.variant});

  @override
  State<SstpVpnApp> createState() => _SstpVpnAppState();
}

class _SstpVpnAppState extends State<SstpVpnApp> {
  late final VpnViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = VpnViewModel(repository: VpnRepository());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSTP Shield',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: MainVpnScreen(viewModel: _viewModel, variant: widget.variant),
    );
  }
}

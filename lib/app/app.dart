import 'package:flutter/material.dart';

import '../data/repositories/vpn_repository.dart';
import '../ui/core/theme.dart';
import '../ui/features/vpn/view_models/vpn_view_model.dart';
import '../ui/features/vpn/views/main_vpn_screen.dart';

class SstpVpnApp extends StatefulWidget {
  const SstpVpnApp({super.key});

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
      home: MainVpnScreen(viewModel: _viewModel),
    );
  }
}

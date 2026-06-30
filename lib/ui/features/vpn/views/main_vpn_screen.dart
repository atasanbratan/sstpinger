import 'package:flutter/material.dart';

import '../view_models/vpn_view_model.dart';
import 'username_screen.dart';
import 'widgets/connection_control_card.dart';
import 'widgets/connection_status_panel.dart';
import 'widgets/profile_settings_sheet.dart';
import 'widgets/server_list_view.dart';
import 'widgets/speed_indicator.dart';

class MainVpnScreen extends StatefulWidget {
  final VpnViewModel viewModel;

  const MainVpnScreen({super.key, required this.viewModel});

  @override
  State<MainVpnScreen> createState() => _MainVpnScreenState();
}

class _MainVpnScreenState extends State<MainVpnScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.onErrorMessage = _showSnackBar;
  }

  @override
  void dispose() {
    if (widget.viewModel.onErrorMessage == _showSnackBar) {
      widget.viewModel.onErrorMessage = null;
    }
    super.dispose();
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
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

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        if (!vm.initialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00D2FF)),
            ),
          );
        }

        if (vm.username.isEmpty) {
          return UsernameScreen(viewModel: vm);
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    letterSpacing: 2,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Refresh server list',
                onPressed: vm.isFetchingServers ? null : vm.fetchServers,
              ),
              IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white70,
                ),
                tooltip: 'Settings / Profile',
                onPressed: _showProfileAndSettingsModal,
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFF00D2FF),
              onRefresh: vm.fetchServers,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      ConnectionStatusPanel(
                        viewModel: vm,
                        onToggle: vm.toggleVpnConnection,
                        formatDuration: _formatDuration,
                      ),
                      const SizedBox(height: 25),
                      ConnectionControlCard(
                        viewModel: vm,
                        getFlagEmoji: _getFlagEmoji,
                        buildSpeedIndicator: _buildSpeedIndicator,
                      ),
                      const SizedBox(height: 20),
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
                            '${vm.getFilteredServers().length} Available',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildSearchField(vm),
                      const SizedBox(height: 12),
                      ServerListView(
                        viewModel: vm,
                        getFlagEmoji: _getFlagEmoji,
                        onEditUsername: _promptEditUsername,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeedIndicator({
    required String label,
    required String speed,
    required String total,
    required IconData icon,
    required Color color,
  }) {
    return SpeedIndicator(
      label: label,
      speed: speed,
      total: total,
      icon: icon,
      color: color,
    );
  }

  Widget _buildSearchField(VpnViewModel vm) {
    return TextField(
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search by country or hostname...',
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
        suffixIcon: vm.searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                onPressed: () => vm.updateSearchQuery(''),
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
      onChanged: vm.updateSearchQuery,
    );
  }

  void _showProfileAndSettingsModal() {
    final vm = widget.viewModel;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ProfileSettingsSheet(
          viewModel: vm,
          onEditUsername: () {
            Navigator.pop(context);
            _promptEditUsername();
          },
          onUseCustomConfigChanged: (val) {
            vm.setUseCustomConfig(val);
          },
        );
      },
    );
  }

  void _promptEditUsername() {
    final vm = widget.viewModel;
    final TextEditingController textController = TextEditingController(
      text: vm.username,
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
                  vm.saveUsername(textController.text);
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

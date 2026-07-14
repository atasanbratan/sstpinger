import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_variant.dart';
import '../../../core/app_colors.dart';
import '../view_models/vpn_view_model.dart';
import 'activation_screen.dart';
import 'subscription_screen.dart';
import 'widgets/connection_control_card.dart';
import 'widgets/connection_status_panel.dart';
import 'widgets/profile_settings_sheet.dart';
import 'widgets/server_list_view.dart';

class MainVpnScreen extends StatefulWidget {
  final VpnViewModel viewModel;
  final AppVariant variant;

  const MainVpnScreen({
    super.key,
    required this.viewModel,
    this.variant = AppVariant.local,
  });

  @override
  State<MainVpnScreen> createState() => _MainVpnScreenState();
}

class _MainVpnScreenState extends State<MainVpnScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.onErrorMessage = _showSnackBar;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.viewModel.onErrorMessage == _showSnackBar) {
      widget.viewModel.onErrorMessage = null;
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollController.hasClients &&
        _scrollController.offset > 300;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  void _scrollToTop() {
    _scrollController.jumpTo(0);
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
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
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }

        if (vm.username.isEmpty || vm.isSubscriptionExpired) {
          return widget.variant.isForeign
              ? SubscriptionScreen(viewModel: vm)
              : ActivationScreen(viewModel: vm);
        }

        return Scaffold(
          floatingActionButton: _showScrollToTop
              ? FloatingActionButton(
                  mini: true,
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.surfaceDeep,
                  tooltip: 'Scroll to top',
                  onPressed: _scrollToTop,
                  child: const Icon(Icons.keyboard_arrow_up_rounded),
                )
              : null,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () async {},
              // onRefresh: vm.fetchServers,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    title: Row(
                      children: [
                        Image.asset(
                          'assets/logo/logo.png',
                          width: 28,
                          height: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SSTP SHIELD',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                letterSpacing: 2,
                                fontSize: 20,
                              ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: vm.isPinging
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                Icons.speed,
                                color: vm.isConnected
                                    ? Colors.white24
                                    : Colors.white70,
                              ),
                        tooltip: vm.isConnected
                            ? "Disconnect to ping servers"
                            : "Sort by Ping",
                        onPressed: vm.isPinging ? null : vm.sortServersByPing,
                      ),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          ConnectionStatusPanel(
                            viewModel: vm,
                            onToggle: vm.toggleVpnConnection,
                          ),
                          const SizedBox(height: 25),
                          ConnectionControlCard(viewModel: vm),
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
                                vm.isPinging
                                    ? 'Pinging ${vm.pingProgress}/${vm.pingTotal} · ${vm.pingPercent}%'
                                    : '${vm.getFilteredServers().length} Available',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: vm.isPinging
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: vm.isPinging
                                      ? AppColors.accent
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          if (vm.isPinging) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: vm.pingTotal == 0
                                    ? null
                                    : vm.pingProgress / vm.pingTotal,
                                minHeight: 4,
                                backgroundColor: AppColors.surface,
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          _buildSearchField(vm),
                          const SizedBox(height: 12),
                          ServerListView(
                            viewModel: vm,
                            onEditUsername: _promptEditUsername,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField(VpnViewModel vm) {
    return TextField(
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search by country or hostname...',
        hintStyle: const TextStyle(color: AppColors.textFaint),
        prefixIcon: const Icon(
          Icons.search,
          color: AppColors.textMuted,
          size: 20,
        ),
        suffixIcon: vm.searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onPressed: () => vm.updateSearchQuery(''),
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
      ),
      onChanged: vm.updateSearchQuery,
    );
  }

  void _openSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => SubscriptionScreen(
          viewModel: widget.viewModel,
          onCompleted: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  void _showProfileAndSettingsModal() {
    final vm = widget.viewModel;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isForeign = widget.variant.isForeign;
        return ProfileSettingsSheet(
          viewModel: vm,
          onEditUsername: () {
            Navigator.pop(context);
            _promptEditUsername();
          },
          renewLabel:
              isForeign ? 'SUBSCRIBE / EXTEND' : 'RENEW ACTIVATION CODE',
          onRenew: () {
            Navigator.pop(context);
            if (isForeign) {
              _openSubscription();
            } else {
              _renewActivationCode();
            }
          },
          onUseCustomConfigChanged: (val) {
            vm.setUseCustomConfig(val);
          },
        );
      },
    );
  }

  Future<void> _renewActivationCode() async {
    final vm = widget.viewModel;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();

    if (!mounted) return;

    if (text == null || text.isEmpty) {
      _showSnackBar('Clipboard is empty. Copy your renewal code first.');
      return;
    }

    final success = await vm.importActivationCode(text);
    if (!mounted) return;

    // Failure is already surfaced by the view model's error callback.
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Activation code renewed!',
            style: TextStyle(fontFamily: 'Outfit'),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
          backgroundColor: AppColors.surface,
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
                borderSide: BorderSide(color: AppColors.accent),
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
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        );
      },
    );
  }
}

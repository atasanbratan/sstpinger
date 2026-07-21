import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_variant.dart';
import '../../domain/entities/app_update_info.dart';
import '../../domain/entities/tunnel_config.dart';
import '../../domain/entities/tunnel_status.dart';
import '../bloc/connection/connection_bloc.dart';
import '../../core/utils/apk_installer.dart';
import '../bloc/vpn/vpn_bloc.dart';
import '../theme/app_colors.dart';
import '../widgets/apk_download_sheet.dart';
import '../widgets/app_update_banner.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/power_button.dart';
import '../widgets/profile_settings_sheet.dart';
import '../widgets/server_list_view.dart';
import 'activation_screen.dart';
import 'subscription_screen.dart';

class MainVpnScreen extends StatefulWidget {
  final AppVariant variant;

  const MainVpnScreen({super.key, this.variant = AppVariant.local});

  @override
  State<MainVpnScreen> createState() => _MainVpnScreenState();
}

class _MainVpnScreenState extends State<MainVpnScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  // App version, shown beside the title once loaded (empty until then).
  String _version = '';

  // Whether the blocking "must update" dialog is currently on screen, so the
  // listener does not re-push it on every state rebuild while below minVersion.
  bool _forcedDialogShown = false;

  // Cancel token for an in-progress APK download; null when idle.
  CancelToken? _apkCancelToken;

  // Custom-config input lives in the widget layer (transient UI, not app state).
  final _customHostController = TextEditingController();
  final _customPortController = TextEditingController(text: '443');
  final _customUsernameController = TextEditingController(text: 'vpn');
  final _customPasswordController = TextEditingController(text: 'vpn');

  // The search field's own text buffer. Needed because the field is otherwise
  // uncontrolled: the "clear" (x) button used to only dispatch an empty query
  // to the bloc — the list cleared, but the typed characters stayed visible
  // since nothing told the TextField itself to erase them.
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
    // If a fetch already landed before the version resolved, the forced-update
    // listener would have skipped it (its listenWhen gates on the version being
    // known) — re-check now that we have one.
    _maybeShowForcedDialog(context.read<VpnBloc>().state);
  }

  /// Pushes the blocking dialog exactly once when the running version is below
  /// the backend's `minVersion`. Guarded by [_forcedDialogShown] to avoid
  /// re-pushing on every state rebuild while the client stays behind min.
  void _maybeShowForcedDialog(VpnState state) {
    if (!mounted || _version.isEmpty || _forcedDialogShown) return;
    if (state.appUpdateInfo.statusOf(_version) != AppUpdateStatus.required) {
      return;
    }
    _forcedDialogShown = true;
    AppUpdateDialog.show(
      context,
      updateInfo: state.appUpdateInfo,
      onTapDownload: () => _openUpdateUrl(state.appUpdateInfo),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _customHostController.dispose();
    _customPortController.dispose();
    _customUsernameController.dispose();
    _customPasswordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow =
        _scrollController.hasClients && _scrollController.offset > 300;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Outfit')),
        backgroundColor: isError ? AppColors.error : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Opens the update: in-app APK download on Android, browser on desktop.
  ///
  /// The updater must never be able to block the app, so every error path
  /// degrades to a SnackBar rather than a crash or an unhandled exception.
  Future<void> _openUpdateUrl(AppUpdateInfo updateInfo) async {
    final version = updateInfo.latestVersion;
    if (Platform.isAndroid && ApkInstaller.isSupported && version != null) {
      await _downloadAndInstall(updateInfo, version);
      return;
    }
    // Desktop / fallback: open the releases page in the system browser.
    await _launchBrowser(updateInfo.updateUrl);
  }

  /// Android-only: downloads the per-ABI APK and invokes the system installer.
  Future<void> _downloadAndInstall(
    AppUpdateInfo updateInfo,
    String version,
  ) async {
    // Build the direct-download URL for this device's ABI and variant.
    final String apkUrl;
    try {
      apkUrl = await ApkInstaller.apkUrl(
        version: version,
        variant: widget.variant.name, // 'local' | 'foreign'
      );
    } catch (_) {
      // ABI detection failed — fall back to the browser.
      await _launchBrowser(updateInfo.updateUrl);
      return;
    }

    // Set up a StreamController to drive the progress sheet.
    final progressController = StreamController<double>.broadcast();
    _apkCancelToken = CancelToken();
    String? savedPath;

    if (!mounted) return;
    // Show the download sheet; it closes itself when the caller pops.
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ApkDownloadSheet(
        version: version,
        progressStream: progressController.stream,
        onInstall: () {
          Navigator.of(context).pop(); // close the sheet
          final path = savedPath;
          if (path != null) {
            ApkInstaller.install(path).then((ok) {
              if (!ok && mounted) {
                _showSnackBar(
                  'Could not open the installer. Try installing manually.',
                  isError: false,
                );
              }
            });
          }
        },
        onCancel: () {
          _apkCancelToken?.cancel();
          Navigator.of(context).pop();
        },
      ),
    );

    // Run the download after the sheet is visible.
    try {
      savedPath = await ApkInstaller.download(
        apkUrl,
        onProgress: (p) {
          if (!progressController.isClosed) progressController.add(p);
        },
        cancelToken: _apkCancelToken,
      );
      // Signal completion (sheet switches to "Install" button).
      if (!progressController.isClosed) progressController.add(1.0);
    } on DioException catch (e) {
      if (!progressController.isClosed) progressController.close();
      if (e.type == DioExceptionType.cancel) return; // user cancelled — silent
      if (mounted) {
        Navigator.of(context).pop(); // close the sheet
        _showSnackBar(
          'Download failed. Please try again or visit the releases page.',
          isError: true,
        );
      }
    } catch (_) {
      if (!progressController.isClosed) progressController.close();
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('An unexpected error occurred during download.', isError: true);
      }
    } finally {
      _apkCancelToken = null;
      await progressController.close();
    }
  }

  /// Opens [url] in the system browser, degrading to a SnackBar on failure.
  Future<void> _launchBrowser(String? url) async {
    if (url == null) {
      _showSnackBar('No download link is available yet.', isError: false);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAbsolutePath) {
      _showSnackBar('The download link is invalid.', isError: false);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _showSnackBar('Could not open the download link.', isError: false);
    }
  }

  /// Connect if idle, disconnect if active. Builds the tunnel config from the
  /// selected server or the custom-config inputs, validating first.
  void _toggleConnection(VpnState vpn, bool isActive) {
    final connection = context.read<ConnectionBloc>();
    if (isActive) {
      connection.add(const DisconnectRequested());
      return;
    }

    if (!vpn.useCustomConfig && vpn.selectedServer == null) {
      _showSnackBar('Please select a VPN server first.');
      return;
    }

    final host = vpn.useCustomConfig
        ? _customHostController.text.trim()
        : vpn.selectedServer!.ip;
    final port = vpn.useCustomConfig
        ? (int.tryParse(_customPortController.text) ?? 443)
        : vpn.selectedServer!.port;
    final username = vpn.useCustomConfig
        ? _customUsernameController.text.trim()
        : 'vpn';
    final password = vpn.useCustomConfig
        ? _customPasswordController.text
        : 'vpn';

    if (host.isEmpty) {
      _showSnackBar('Host address cannot be empty.');
      return;
    }

    connection.add(
      ConnectRequested(
        TunnelConfig(
          host: host,
          port: port,
          username: username,
          password: password,
          label: vpn.useCustomConfig ? host : vpn.selectedServer!.country,
          protocol: vpn.protocol,
          softEtherDisableNatT: vpn.softEtherDisableNatT,
          softEtherNatTRetryWaitSeconds: vpn.softEtherNatTRetryWaitSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Global user messages (errors + info) from the feature bloc.
        BlocListener<VpnBloc, VpnState>(
          listenWhen: (p, c) =>
              c.message != null && c.message!.id != p.message?.id,
          listener: (context, state) => _showSnackBar(
            state.message!.text,
            isError: state.message!.isError,
          ),
        ),
        // Tunnel errors from the connection bloc.
        BlocListener<ConnectionBloc, VpnConnectionState>(
          listenWhen: (p, c) => c.error != null && c.error!.id != p.error?.id,
          listener: (context, state) => _showSnackBar(state.error!.message),
        ),
        // On reaching connected: refresh the server list (once per session) and
        // record the server in Recents (skip custom-config connects — no node).
        BlocListener<ConnectionBloc, VpnConnectionState>(
          listenWhen: (p, c) =>
              p.status != TunnelStatus.connected &&
              c.status == TunnelStatus.connected,
          listener: (context, _) {
            final bloc = context.read<VpnBloc>();
            bloc.add(const ServersRefreshRequested());
            final vpn = bloc.state;
            if (!vpn.useCustomConfig && vpn.selectedServer != null) {
              bloc.add(ServerConnected(vpn.selectedServer!));
            }
          },
        ),
        // The renew-from-profile flow confirms success here (the gate screens
        // handle their own success by transitioning).
        BlocListener<VpnBloc, VpnState>(
          listenWhen: (p, c) =>
              c.actionResult != null &&
              c.actionResult!.id != p.actionResult?.id &&
              c.actionResult!.kind == VpnActionKind.activation &&
              c.actionResult!.success,
          listener: (context, _) =>
              _showSnackBar('Activation code renewed!', isError: false),
        ),
        // Forced update: when the backend says the running build is below
        // minVersion, push the blocking dialog once. Advisory newer-build
        // banners are rendered inline in the body instead.
        BlocListener<VpnBloc, VpnState>(
          listenWhen: (p, c) =>
              c.appUpdateInfo != p.appUpdateInfo && _version.isNotEmpty,
          listener: (context, state) => _maybeShowForcedDialog(state),
        ),
      ],
      child: BlocBuilder<VpnBloc, VpnState>(
        builder: (context, vpn) {
          if (!vpn.initialized) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            );
          }

          if (vpn.needsOnboarding) {
            return widget.variant.isForeign
                ? const SubscriptionScreen()
                : const ActivationScreen();
          }

          return _buildConnectedScaffold(context, vpn);
        },
      ),
    );
  }

  /// Wide enough for a Happ-style two-pane desktop layout (server list on the
  /// left, connection hero on the right). Below this, the single-column mobile
  /// layout is used.
  static const double _wideBreakpoint = 820;

  Widget _buildConnectedScaffold(BuildContext context, VpnState vpn) {
    return Scaffold(
      appBar: _buildAppBar(context),
      // The scroll-to-top FAB only makes sense for the single scroll column.
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.surfaceDeep,
              tooltip: 'Scroll to top',
              onPressed: () => _scrollController.jumpTo(0),
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_shouldShowUpdateBanner(vpn))
              AppUpdateBanner(
                updateInfo: vpn.appUpdateInfo,
                onTapDownload: () => _openUpdateUrl(vpn.appUpdateInfo),
                onDismiss: () => context
                    .read<VpnBloc>()
                    .add(const UpdateBannerDismissed()),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= _wideBreakpoint
                        ? _buildWideBody(context, vpn)
                        : _buildNarrowBody(context, vpn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Advisory banner gate: a newer build exists (but not below `minVersion`),
  /// and the user has not dismissed it this session for this `latestVersion`.
  /// The blocking `required` case never reaches here — it's a dialog instead.
  bool _shouldShowUpdateBanner(VpnState vpn) {
    if (_version.isEmpty || vpn.updateBannerDismissed) return false;
    return vpn.appUpdateInfo.statusOf(_version) == AppUpdateStatus.optional;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.settings_outlined, color: Colors.white70),
        tooltip: 'Settings / Profile',
        onPressed: _showProfileAndSettingsModal,
      ),
      title: Row(
        children: [
          Image.asset('assets/logo/logo.png', width: 24, height: 24),
          const SizedBox(width: 8),
          Text(
            'SSTP SHIELD',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              letterSpacing: 2,
              fontSize: 17,
            ),
          ),
          if (_version.isNotEmpty) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'v$_version',
                style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Single-column (mobile): the hero sits at the top, sized to its content
  /// (not a fixed share of the screen) so the server list beneath it — the
  /// thing users actually scroll through — gets the rest of the height.
  Widget _buildNarrowBody(BuildContext context, VpnState vpn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
          child: Center(child: _buildHero(context, vpn)),
        ),
        Expanded(child: _buildServersSection(context, vpn)),
      ],
    );
  }

  /// Two-pane (desktop): scrollable server list on the left, connection hero
  /// centred on the right — the Happ desktop arrangement.
  Widget _buildWideBody(BuildContext context, VpnState vpn) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left pane: the server list, taking half the window width.
        Expanded(child: _buildServersSection(context, vpn)),
        const VerticalDivider(width: 1, color: AppColors.divider),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _buildHero(context, vpn),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The power button and the node it will use.
  Widget _buildHero(BuildContext context, VpnState vpn) {
    return BlocBuilder<ConnectionBloc, VpnConnectionState>(
      builder: (context, conn) => Column(
        children: [
          PowerButton(
            status: conn.status,
            onToggle: () => _toggleConnection(vpn, conn.isConnected),
          ),
        ],
      ),
    );
  }

  /// The server picker: header/search/ping-progress ride as the scrolling
  /// header of [ServerListView]'s own `CustomScrollView`, so the tabbed list
  /// beneath it can be lazily built via `SliverList.builder` instead of an
  /// eagerly-built `Column` of every server row.
  Widget _buildServersSection(BuildContext context, VpnState vpn) {
    return ServerListView(
      scrollController: _scrollController,
      header: _buildServersHeaderBlock(vpn),
    );
  }

  Widget _buildServersHeaderBlock(VpnState vpn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildServersHeader(vpn),
        const SizedBox(height: 10),
        _buildSearchRow(vpn),
        if (vpn.isPinging) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: vpn.pingTotal == 0 ? null : vpn.pingProgress / vpn.pingTotal,
              minHeight: 3,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildServersHeader(VpnState vpn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Servers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        _buildServerCount(vpn),
      ],
    );
  }

  /// Right-aligned count: "N available", plus a green "· M reachable" clause once
  /// servers have been pinged. Shows ping progress while a ping is running.
  Widget _buildServerCount(VpnState vpn) {
    if (vpn.isPinging) {
      return Text(
        'Pinging ${vpn.pingProgress}/${vpn.pingTotal} · ${vpn.pingPercent}%',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
        ),
      );
    }

    final servers = vpn.filteredServers;
    final reachable = servers.where((s) => s.ping != null).length;
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
        children: [
          TextSpan(text: '${servers.length} available'),
          if (reachable > 0)
            TextSpan(
              text: ' · $reachable reachable',
              style: const TextStyle(
                color: AppColors.pingGood,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  /// Search field with the ping-all action beside it, as in Happ's server pane.
  Widget _buildSearchRow(VpnState vpn) {
    return BlocBuilder<ConnectionBloc, VpnConnectionState>(
      builder: (context, conn) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Type here to search',
                hintStyle: const TextStyle(color: AppColors.textFaint),
                suffixIcon: vpn.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          context.read<VpnBloc>().add(
                            const SearchQueryChanged(''),
                          );
                        },
                      )
                    : const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentBorder),
                ),
              ),
              onChanged: (q) =>
                  context.read<VpnBloc>().add(SearchQueryChanged(q)),
            ),
          ),
          const SizedBox(width: 8),
          // Ping every server and sort fastest-first.
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: conn.isConnected
                  ? 'Disconnect to ping servers'
                  : 'Ping all and sort',
              onPressed: vpn.isPinging
                  ? null
                  : () => context.read<VpnBloc>().add(
                      PingRequested(isConnected: conn.isConnected),
                    ),
              icon: vpn.isPinging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : Icon(
                      Icons.speed_rounded,
                      color: conn.isConnected
                          ? AppColors.textFaint
                          : AppColors.accent,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Fetch the latest server list from the backend.
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: 'Fetch latest servers',
              onPressed: vpn.isFetchingServers
                  ? null
                  : () => context.read<VpnBloc>().add(
                      const ServersFetchRequested(),
                    ),
              icon: vpn.isFetchingServers
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      color: AppColors.accent,
                    ),
            ),
          ),
        ],
      ),
    );
  }


  void _openSubscription() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => SubscriptionScreen(
          onCompleted: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  void _showProfileAndSettingsModal() {
    final isForeign = widget.variant.isForeign;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => ProfileSettingsSheet(
          customHostController: _customHostController,
          customPortController: _customPortController,
          customUsernameController: _customUsernameController,
          customPasswordController: _customPasswordController,
          onEditUsername: () {
            Navigator.pop(routeContext);
            _promptEditUsername();
          },
          renewLabel: isForeign ? 'SUBSCRIBE / EXTEND' : 'RENEW ACTIVATION CODE',
          onRenew: () {
            Navigator.pop(routeContext);
            if (isForeign) {
              _openSubscription();
            } else {
              _renewActivationCode();
            }
          },
          // Loading the code from a file is a local-variant hand-off; the foreign
          // variant renews by paying, so it has no file option.
          onRenewFromFile: isForeign
              ? null
              : () {
                  Navigator.pop(routeContext);
                  _renewActivationCodeFromFile();
                },
        ),
      ),
    );
  }

  Future<void> _renewActivationCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted) return;

    if (text == null || text.isEmpty) {
      _showSnackBar('Clipboard is empty. Copy your renewal code first.');
      return;
    }

    // Success ("renewed!") is confirmed by the actionResult listener; a failure
    // surfaces through the message listener.
    context.read<VpnBloc>().add(ActivationCodeSubmitted(text));
  }

  /// Renew by loading the activation-code `.txt` the admin console saves, instead
  /// of pasting from the clipboard.
  Future<void> _renewActivationCodeFromFile() async {
    const group = XTypeGroup(label: 'Activation code', extensions: ['txt']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null || !mounted) return; // cancelled

    final text = (await file.readAsString()).trim();
    if (!mounted) return;

    if (text.isEmpty) {
      _showSnackBar('That file is empty. Pick your activation code file.');
      return;
    }

    context.read<VpnBloc>().add(ActivationCodeSubmitted(text));
  }

  void _promptEditUsername() {
    final controller = TextEditingController(
      text: context.read<VpnBloc>().state.username,
    );
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Change Username',
            style: TextStyle(color: Colors.white, fontFamily: 'Outfit'),
          ),
          content: TextField(
            controller: controller,
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  context.read<VpnBloc>().add(UsernameChanged(controller.text));
                  Navigator.pop(dialogContext);
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

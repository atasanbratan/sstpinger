import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/support_config.dart';
import '../../core/utils/formatters.dart';
import '../bloc/connection/connection_bloc.dart';
import '../bloc/vpn/vpn_bloc.dart';
import '../screens/settings/custom_node_screen.dart';
import '../screens/settings/diagnostic_logs_screen.dart';
import '../screens/settings/faq_screen.dart';
import '../screens/settings/fetch_count_screen.dart';
import '../screens/settings/ping_settings_screen.dart';
import '../screens/settings/proxy_sharing_screen.dart';
import '../screens/settings/protocol_screen.dart';
import '../screens/settings/reconnect_settings_screen.dart';
import '../screens/settings/sessions_screen.dart';
import '../screens/settings/softether_natt_screen.dart';
import '../screens/settings/static_info_screen.dart';
import '../theme/app_colors.dart';
import 'profile_settings/renew_buttons.dart';
import 'profile_settings/settings_bottom_sheet.dart';
import 'profile_settings/settings_group_card.dart';
import 'profile_settings/settings_row.dart';
import 'profile_settings/settings_section_header.dart';

class ProfileSettingsSheet extends StatelessWidget {
  final VoidCallback onEditUsername;
  final VoidCallback onRenew;

  /// Renew by loading the activation-code file (the admin console's Download).
  final VoidCallback? onRenewFromFile;
  final VoidCallback onSubscribe;
  final TextEditingController customHostController;
  final TextEditingController customPortController;
  final TextEditingController customUsernameController;
  final TextEditingController customPasswordController;

  const ProfileSettingsSheet({
    super.key,
    required this.onEditUsername,
    required this.onRenew,
    this.onRenewFromFile,
    required this.onSubscribe,
    required this.customHostController,
    required this.customPortController,
    required this.customUsernameController,
    required this.customPasswordController,
  });

  /// SoftEther is desktop-only, so the protocol picker is too.
  bool get _isDesktop => !Platform.isAndroid && !Platform.isIOS;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String _proxySharingLabel(BuildContext context, VpnState vpn) {
    if (!vpn.proxySharingEnabled) return 'Off';
    final port = context.select<ConnectionBloc, int?>(
      (b) => b.state.proxySharingPort,
    );
    return port == null ? 'On' : 'On · $port';
  }

  void _copyDeviceId(BuildContext context, String deviceId) {
    Clipboard.setData(ClipboardData(text: deviceId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Device ID copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _contactUs(BuildContext context) async {
    if (SupportConfig.supportEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Support contact isn't configured yet.")),
      );
      return;
    }
    await launchUrl(Uri(scheme: 'mailto', path: SupportConfig.supportEmail));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'SETTINGS & PROFILE',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ),
      body: BlocBuilder<VpnBloc, VpnState>(
        builder: (context, vpn) {
          final bloc = context.read<VpnBloc>();
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SettingsSectionHeader('ACCOUNT'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  rows: [
                    SettingsRow(
                      icon: Icons.person,
                      title: 'Username',
                      trailingText: vpn.username,
                      onTap: onEditUsername,
                    ),
                    SettingsRow(
                      icon: Icons.phone_android,
                      iconColor: AppColors.accentSecondary,
                      title: 'Device ID',
                      trailingText: vpn.deviceId,
                      onTap: () => _copyDeviceId(context, vpn.deviceId),
                    ),
                    SettingsRow(
                      icon: vpn.isSubscriptionExpired
                          ? Icons.error_outline
                          : Icons.workspace_premium_outlined,
                      iconColor: vpn.isSubscriptionExpired
                          ? AppColors.error
                          : AppColors.accent,
                      title: vpn.isSubscriptionExpired
                          ? 'Expired on'
                          : 'Expires on',
                      subtitle: vpn.isSubscriptionExpired
                          ? null
                          : Formatters.remaining(vpn.expireTime),
                      trailingText: Formatters.date(vpn.expireTime),
                      trailingTextColor: vpn.isSubscriptionExpired
                          ? AppColors.error
                          : null,
                      onTap: onSubscribe,
                    ),
                    SettingsRow(
                      icon: Icons.update,
                      iconColor: AppColors.textMuted,
                      title: 'Server list last updated',
                      trailingText: Formatters.date(vpn.lastFetchTime),
                    ),
                    if (vpn.hasSession)
                      SettingsRow(
                        icon: Icons.account_circle_outlined,
                        iconColor: AppColors.accent,
                        title: 'Google account',
                        trailingText: vpn.email,
                      ),
                    if (vpn.hasSession)
                      SettingsRow(
                        icon: Icons.devices_outlined,
                        title: 'Active sessions',
                        subtitle: 'Manage devices signed in to your account',
                        showChevron: true,
                        onTap: () => _push(context, const SessionsScreen()),
                      ),
                    if (vpn.hasSession)
                      SettingsRow(
                        icon: Icons.logout,
                        iconColor: AppColors.error,
                        title: 'Sign out',
                        onTap: () {
                          context.read<VpnBloc>().add(const SignOutRequested());
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                RenewButtons(
                  onRenew: onRenew,
                  onRenewFromFile: onRenewFromFile,
                  onSubscribe: onSubscribe,
                ),
                const SizedBox(height: 20),
                const SettingsSectionHeader('NETWORK'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  rows: [
                    SettingsRow(
                      icon: Icons.public_rounded,
                      title: 'Curated region pool',
                      subtitle: 'Only servers verified reachable from that ISP',
                      switchValue: vpn.useCuratedRegion,
                      onSwitchChanged: (v) =>
                          bloc.add(RegionPoolChanged(v)),
                    ),
                    if (_isDesktop)
                      SettingsRow(
                        icon: Icons.shield_outlined,
                        title: 'Protocol',
                        trailingText: vpn.protocol.label,
                        showChevron: true,
                        onTap: () => showSettingsBottomSheet(
                          context,
                          title: 'Protocol',
                          child: const ProtocolScreen(),
                        ),
                      ),
                    if (_isDesktop)
                      SettingsRow(
                        icon: Icons.lan_rounded,
                        title: 'SoftEther transport',
                        trailingText:
                            vpn.softEtherDisableNatT ? 'NAT-T off' : 'NAT-T on',
                        showChevron: true,
                        onTap: () => showSettingsBottomSheet(
                          context,
                          title: 'SoftEther Transport',
                          child: const SoftEtherNattScreen(),
                        ),
                      ),
                    SettingsRow(
                      icon: Icons.share_rounded,
                      title: 'Proxy sharing',
                      trailingText: _proxySharingLabel(context, vpn),
                      showChevron: true,
                      onTap: () => showSettingsBottomSheet(
                        context,
                        title: 'Proxy Sharing',
                        child: const ProxySharingScreen(),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.timer_outlined,
                      title: 'Ping settings',
                      showChevron: true,
                      onTap: () => showSettingsBottomSheet(
                        context,
                        title: 'Ping Settings',
                        child: const PingSettingsScreen(),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.dns_rounded,
                      title: 'Server fetch count',
                      trailingText: '${vpn.fetchServerCount}',
                      showChevron: true,
                      onTap: () => showSettingsBottomSheet(
                        context,
                        title: 'Server List',
                        child: const FetchCountScreen(),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.refresh_rounded,
                      title: 'Reconnection',
                      showChevron: true,
                      onTap: () => showSettingsBottomSheet(
                        context,
                        title: 'Reconnection',
                        child: const ReconnectSettingsScreen(),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.tune,
                      title: 'Custom node',
                      trailingText: vpn.useCustomConfig ? 'On' : 'Off',
                      showChevron: true,
                      onTap: () => _push(
                        context,
                        CustomNodeScreen(
                          hostController: customHostController,
                          portController: customPortController,
                          usernameController: customUsernameController,
                          passwordController: customPasswordController,
                        ),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.description_outlined,
                      title: 'Diagnostic logs',
                      showChevron: true,
                      onTap: () =>
                          _push(context, const DiagnosticLogsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const SettingsSectionHeader('APP'),
                const SizedBox(height: 8),
                SettingsGroupCard(
                  rows: [
                    SettingsRow(
                      icon: Icons.mail_outline,
                      title: 'Contact Us',
                      showChevron: true,
                      onTap: () => _contactUs(context),
                    ),
                    SettingsRow(
                      icon: Icons.help_outline,
                      title: 'FAQ',
                      showChevron: true,
                      onTap: () => _push(context, const FaqScreen()),
                    ),
                    SettingsRow(
                      icon: Icons.security,
                      title: 'Privacy & Security',
                      showChevron: true,
                      onTap: () => _push(
                        context,
                        const StaticInfoScreen(
                          title: 'Privacy & Security',
                          body: 'TODO: insert policy text',
                        ),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      showChevron: true,
                      onTap: () => _push(
                        context,
                        const StaticInfoScreen(
                          title: 'Privacy Policy',
                          body: 'TODO: insert policy text',
                        ),
                      ),
                    ),
                    SettingsRow(
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      showChevron: true,
                      onTap: () => _push(
                        context,
                        const StaticInfoScreen(
                          title: 'Terms of Service',
                          body: 'TODO: insert policy text',
                        ),
                      ),
                    ),
                    const _VersionRow(),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Real app version + build number, e.g. "3.2.0 (12)".
class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final text = info == null ? '…' : '${info.version} (${info.buildNumber})';
        return SettingsRow(
          icon: Icons.info_outline,
          iconColor: AppColors.textMuted,
          title: 'Version',
          trailingText: text,
        );
      },
    );
  }
}

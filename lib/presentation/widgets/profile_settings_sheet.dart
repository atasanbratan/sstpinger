import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/vpn/vpn_bloc.dart';
import '../theme/app_colors.dart';
import 'profile_settings/custom_node_settings.dart';
import 'profile_settings/fetch_count_card.dart';
import 'profile_settings/log_path_row.dart';
import 'profile_settings/ping_mode_card.dart';
import 'profile_settings/ping_settings_card.dart';
import 'profile_settings/protocol_card.dart';
import 'profile_settings/reconnect_settings_card.dart';
import 'profile_settings/renew_buttons.dart';
import 'profile_settings/settings_section_header.dart';
import 'profile_settings/softether_natt_card.dart';
import 'profile_settings/subscription_card.dart';
import 'profile_settings/user_profile_card.dart';

class ProfileSettingsSheet extends StatelessWidget {
  final VoidCallback onEditUsername;
  final VoidCallback onRenew;

  /// Renew by loading the activation-code file (the admin console's Download).
  /// Null hides the option (e.g. the foreign variant, which renews via payment).
  final VoidCallback? onRenewFromFile;
  final String renewLabel;
  final TextEditingController customHostController;
  final TextEditingController customPortController;
  final TextEditingController customUsernameController;
  final TextEditingController customPasswordController;

  const ProfileSettingsSheet({
    super.key,
    required this.onEditUsername,
    required this.onRenew,
    this.onRenewFromFile,
    this.renewLabel = 'RENEW ACTIVATION CODE',
    required this.customHostController,
    required this.customPortController,
    required this.customUsernameController,
    required this.customPasswordController,
  });

  /// SoftEther is desktop-only, so the protocol picker is too.
  bool get _isDesktop => !Platform.isAndroid && !Platform.isIOS;

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
                const SettingsSectionHeader('USER PROFILE'),
                const SizedBox(height: 8),
                UserProfileCard(
                  username: vpn.username,
                  deviceId: vpn.deviceId,
                  onEditUsername: onEditUsername,
                ),
                const SizedBox(height: 20),
                const SettingsSectionHeader('SUBSCRIPTION'),
                const SizedBox(height: 8),
                SubscriptionCard(
                  isExpired: vpn.isSubscriptionExpired,
                  expireTime: vpn.expireTime,
                  lastFetchTime: vpn.lastFetchTime,
                ),
                const SizedBox(height: 12),
                RenewButtons(
                  onRenew: onRenew,
                  renewLabel: renewLabel,
                  onRenewFromFile: onRenewFromFile,
                ),
                // Desktop only: SoftEther has no Android/iOS client (and no
                // non-root way to get one), so mobile has a single protocol and
                // the picker would be a control with nothing to choose.
                if (_isDesktop) ...[
                  const SizedBox(height: 20),
                  const SettingsSectionHeader('PROTOCOL'),
                  const SizedBox(height: 8),
                  ProtocolCard(
                    selected: vpn.protocol,
                    onChanged: (p) => bloc.add(ProtocolChanged(p)),
                  ),
                  const SizedBox(height: 20),
                  const SettingsSectionHeader('SOFTETHER TRANSPORT'),
                  const SizedBox(height: 8),
                  SoftEtherNatTCard(
                    disableNatT: vpn.softEtherDisableNatT,
                    onDisableNatTChanged: (v) =>
                        bloc.add(SoftEtherDisableNatTChanged(v)),
                    retryWaitSeconds: vpn.softEtherNatTRetryWaitSeconds,
                    onRetryWaitChanged: (v) =>
                        bloc.add(SoftEtherNatTRetryWaitChanged(v)),
                    onPersist: () =>
                        bloc.add(const SoftEtherNatTSettingsPersistRequested()),
                  ),
                ],
                const LogPathRow(),
                const SizedBox(height: 20),
                const SettingsSectionHeader('PING SETTINGS'),
                const SizedBox(height: 8),
                PingSettingsCard(
                  timeoutSeconds: vpn.pingTimeoutSeconds,
                  onTimeoutChanged: (v) => bloc.add(PingTimeoutChanged(v)),
                  batchSize: vpn.pingBatchSize,
                  onBatchSizeChanged: (v) => bloc.add(PingBatchSizeChanged(v)),
                  onPersist: () =>
                      bloc.add(const PingSettingsPersistRequested()),
                ),
                const SizedBox(height: 10),
                PingModeCard(
                  mode: vpn.pingMode,
                  onChanged: (m) => bloc.add(PingModeChanged(m)),
                ),
                const SizedBox(height: 20),
                const SettingsSectionHeader('SERVER LIST'),
                const SizedBox(height: 8),
                FetchCountCard(
                  count: vpn.fetchServerCount,
                  onChanged: (v) => bloc.add(FetchServerCountChanged(v)),
                  onPersist: () =>
                      bloc.add(const FetchServerCountPersistRequested()),
                ),
                const SizedBox(height: 20),
                const SettingsSectionHeader('RECONNECTION'),
                const SizedBox(height: 8),
                ReconnectSettingsCard(
                  retryCount: vpn.reconnectRetryCount,
                  onRetryCountChanged: (v) =>
                      bloc.add(ReconnectRetryCountChanged(v)),
                  retryIntervalSeconds: vpn.reconnectRetryIntervalSeconds,
                  onRetryIntervalChanged: (v) =>
                      bloc.add(ReconnectRetryIntervalChanged(v)),
                  onPersist: () =>
                      bloc.add(const ReconnectSettingsPersistRequested()),
                ),
                const SizedBox(height: 20),
                CustomNodeSettings(
                  enabled: vpn.useCustomConfig,
                  onEnabledChanged: (v) =>
                      bloc.add(UseCustomConfigChanged(v)),
                  hostController: customHostController,
                  portController: customPortController,
                  usernameController: customUsernameController,
                  passwordController: customPasswordController,
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

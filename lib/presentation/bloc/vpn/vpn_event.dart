part of 'vpn_bloc.dart';

sealed class VpnEvent extends Equatable {
  const VpnEvent();

  @override
  List<Object?> get props => [];
}

/// Bootstrap: load identity, settings, bookmarks, cached servers, then fetch.
class VpnStarted extends VpnEvent {
  const VpnStarted();
}

class ServersFetchRequested extends VpnEvent {
  const ServersFetchRequested();
}

/// Background refresh after connecting; runs at most once per session and only
/// if a refresh is due.
class ServersRefreshRequested extends VpnEvent {
  const ServersRefreshRequested();
}

class SearchQueryChanged extends VpnEvent {
  final String query;
  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class ServerSelected extends VpnEvent {
  final VpnServer server;
  const ServerSelected(this.server);

  @override
  List<Object?> get props => [server];
}

class BookmarkToggled extends VpnEvent {
  final VpnServer server;
  const BookmarkToggled(this.server);

  @override
  List<Object?> get props => [server];
}

/// Fired when the tunnel reaches "connected" for [server]; records it in the
/// recently-connected list (newest first, de-duplicated, capped).
class ServerConnected extends VpnEvent {
  final VpnServer server;
  const ServerConnected(this.server);

  @override
  List<Object?> get props => [server];
}

class UseCustomConfigChanged extends VpnEvent {
  final bool useCustomConfig;
  const UseCustomConfigChanged(this.useCustomConfig);

  @override
  List<Object?> get props => [useCustomConfig];
}

/// Sort all servers by latency. [isConnected] is passed by the screen because
/// pinging is meaningless (and blocked) while the tunnel is up.
class PingRequested extends VpnEvent {
  final bool isConnected;
  const PingRequested({required this.isConnected});

  @override
  List<Object?> get props => [isConnected];
}

class BookmarkPingRequested extends VpnEvent {
  final bool isConnected;
  const BookmarkPingRequested({required this.isConnected});

  @override
  List<Object?> get props => [isConnected];
}

class PingTimeoutChanged extends VpnEvent {
  final double seconds;
  const PingTimeoutChanged(this.seconds);

  @override
  List<Object?> get props => [seconds];
}

class PingBatchSizeChanged extends VpnEvent {
  final int size;
  const PingBatchSizeChanged(this.size);

  @override
  List<Object?> get props => [size];
}

class PingSettingsPersistRequested extends VpnEvent {
  const PingSettingsPersistRequested();
}

class ReconnectRetryCountChanged extends VpnEvent {
  final int count;
  const ReconnectRetryCountChanged(this.count);

  @override
  List<Object?> get props => [count];
}

class ReconnectRetryIntervalChanged extends VpnEvent {
  final int seconds;
  const ReconnectRetryIntervalChanged(this.seconds);

  @override
  List<Object?> get props => [seconds];
}

class ReconnectSettingsPersistRequested extends VpnEvent {
  const ReconnectSettingsPersistRequested();
}

class FetchServerCountChanged extends VpnEvent {
  final int count;
  const FetchServerCountChanged(this.count);

  @override
  List<Object?> get props => [count];
}

class FetchServerCountPersistRequested extends VpnEvent {
  const FetchServerCountPersistRequested();
}

class PingModeChanged extends VpnEvent {
  final PingMode mode;
  const PingModeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}

class SoftEtherDisableNatTChanged extends VpnEvent {
  final bool disable;
  const SoftEtherDisableNatTChanged(this.disable);

  @override
  List<Object?> get props => [disable];
}

class SoftEtherNatTRetryWaitChanged extends VpnEvent {
  final int seconds;
  const SoftEtherNatTRetryWaitChanged(this.seconds);

  @override
  List<Object?> get props => [seconds];
}

class SoftEtherNatTSettingsPersistRequested extends VpnEvent {
  const SoftEtherNatTSettingsPersistRequested();
}

/// Toggles the Servers-tab layout (flat vs grouped) and persists the choice.
class ServersViewModeChanged extends VpnEvent {
  final bool flat;
  const ServersViewModeChanged(this.flat);

  @override
  List<Object?> get props => [flat];
}

/// Selects the tunnel protocol and persists the choice.
class ProtocolChanged extends VpnEvent {
  final TunnelProtocol protocol;
  const ProtocolChanged(this.protocol);

  @override
  List<Object?> get props => [protocol];
}

class UsernameChanged extends VpnEvent {
  final String username;
  const UsernameChanged(this.username);

  @override
  List<Object?> get props => [username];
}

class ActivationCodeSubmitted extends VpnEvent {
  final String base64;
  const ActivationCodeSubmitted(this.base64);

  @override
  List<Object?> get props => [base64];
}

class FreeTrialRequested extends VpnEvent {
  const FreeTrialRequested();
}

/// Starts the interactive Google Sign-In and, on success, fetches servers for
/// the signed-in account.
class GoogleSignInRequested extends VpnEvent {
  const GoogleSignInRequested();
}

/// Signs out of the Google account and returns to the onboarding gate.
class SignOutRequested extends VpnEvent {
  const SignOutRequested();
}

/// Loads the signed-in account's registered device sessions.
class SessionsRequested extends VpnEvent {
  const SessionsRequested();
}

/// Revokes one of the account's own sessions, then reloads the list.
class SessionRevoked extends VpnEvent {
  final int sessionId;
  const SessionRevoked(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class SubscriptionSubmitted extends VpnEvent {
  final String network;
  final String txHash;
  const SubscriptionSubmitted({required this.network, required this.txHash});

  @override
  List<Object?> get props => [network, txHash];
}

/// Toggles sharing the VPN tunnel via a local SOCKS5 proxy. The listening
/// port isn't user-configurable — it's chosen automatically when the
/// listener starts.
class ProxySharingToggled extends VpnEvent {
  final bool enabled;
  const ProxySharingToggled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// Toggles fetching from the curated regional pool vs. the full server list,
/// and persists the choice immediately (like a protocol pick, not a
/// slider-drag setting).
class RegionPoolChanged extends VpnEvent {
  final bool useCuratedRegion;
  const RegionPoolChanged(this.useCuratedRegion);

  @override
  List<Object?> get props => [useCuratedRegion];
}

/// Dismisses the advisory update banner for the current `latestVersion`. It is
/// advisory only — the banner stays hidden this session for that version, but a
/// blocking dialog (version below `minVersion`) ignores it and always shows.
class UpdateBannerDismissed extends VpnEvent {
  const UpdateBannerDismissed();
}

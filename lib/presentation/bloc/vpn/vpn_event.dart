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

class SubscriptionSubmitted extends VpnEvent {
  final String network;
  final String txHash;
  const SubscriptionSubmitted({required this.network, required this.txHash});

  @override
  List<Object?> get props => [network, txHash];
}

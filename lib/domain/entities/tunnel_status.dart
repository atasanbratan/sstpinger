/// The lifecycle state of the VPN tunnel.
///
/// Replaces the stringly-typed `VpnTunnelStatus` constants the UI used to key
/// off. The data layer maps the plugins' string states to these values.
enum TunnelStatus {
  disconnected,
  connecting,
  connected,
  disconnecting;

  /// True while a tunnel is up or coming up — the UI treats both as "on" (e.g.
  /// the connect button becomes a disconnect button, pinging is blocked).
  bool get isActive =>
      this == TunnelStatus.connected || this == TunnelStatus.connecting;
}

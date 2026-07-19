/// How the app measures a server's reachability.
enum PingMode {
  /// Fast: a raw TCP connect. Proves a port is open — not that TLS (what the
  /// VPN actually needs) completes.
  tcp,

  /// Accurate: a TLS handshake, routed through the uTLS relay when bundled so
  /// the result reflects real connectability on fingerprint-filtering networks.
  tls,
}

import 'dart:io';

/// The VPN protocol used to reach a server.
///
/// Every server we list is a SoftEther/VPN Gate node that speaks several
/// protocols on the same host, so this is a choice of *how* to connect, not
/// *which* servers are reachable.
///
/// [sstp] works everywhere. [softEther] drives the official vpnclient/vpncmd and
/// is currently **Linux desktop only** — on Windows and mobile the picker shows
/// it disabled ("soon").
enum TunnelProtocol {
  sstp('SSTP'),
  softEther('SoftEther');

  final String label;

  const TunnelProtocol(this.label);

  /// Whether this protocol can actually connect on the current platform.
  bool get available {
    switch (this) {
      case TunnelProtocol.sstp:
        return true;
      case TunnelProtocol.softEther:
        // Desktop only. Proven on Linux; the Windows path is implemented but
        // still needs field validation. No mobile path yet.
        return Platform.isLinux || Platform.isWindows;
    }
  }

  /// Parses a stored name back to a protocol, defaulting to [sstp].
  static TunnelProtocol fromName(String? name) => TunnelProtocol.values
      .firstWhere((p) => p.name == name, orElse: () => TunnelProtocol.sstp);
}

import 'package:equatable/equatable.dart';

import 'tunnel_protocol.dart';

/// Everything needed to bring a tunnel up. Plain data — no plugin types — so a
/// bloc can build one without knowing which platform will carry it.
class TunnelConfig extends Equatable {
  const TunnelConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.label,
    this.protocol = TunnelProtocol.sstp,
  });

  final String host;
  final int port;
  final String username;
  final String password;

  /// Human-readable server name, e.g. for the Android notification.
  final String label;

  /// Which tunnel protocol to use. Desktop honours it (SSTP vs SoftEther);
  /// mobile is SSTP-only, so it is ignored there.
  final TunnelProtocol protocol;

  @override
  List<Object?> get props => [host, port, username, password, label, protocol];
}

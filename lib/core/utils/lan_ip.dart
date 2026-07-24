import 'dart:io';

/// This device's non-loopback IPv4 addresses, split by what they're for:
/// [lanIp] (a regular LAN adapter — what other devices on the network should
/// point their SOCKS5 client at) vs. [vpnIp] (the address the VPN tunnel
/// assigned this device, identified by its interface name — informational
/// only, not something a peer connects to).
class NetworkAddresses {
  final String? lanIp;
  final String? vpnIp;
  const NetworkAddresses({this.lanIp, this.vpnIp});
}

/// Interface name prefixes used by this app's tunnel backends across
/// platforms: `tun` (Linux, sstp_client's `linux_tun.dart`, default `tun0`),
/// `wintun`/`sstp` (Windows, Wintun-backed adapters), `utun`/`ppp` (unused
/// today but common tunnel-interface names elsewhere).
bool _isTunnelInterface(String name) {
  final n = name.toLowerCase();
  return n.startsWith('tun') ||
      n.startsWith('utun') ||
      n.startsWith('ppp') ||
      n.contains('wintun') ||
      n.contains('sstp');
}

/// Scans local network interfaces and buckets their first non-loopback IPv4
/// address into [NetworkAddresses.lanIp] or [NetworkAddresses.vpnIp] by
/// interface name. Either may be null (e.g. `vpnIp` before the tunnel is up).
Future<NetworkAddresses> currentNetworkAddresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: false,
  );
  String? lanIp;
  String? vpnIp;
  for (final interface in interfaces) {
    for (final addr in interface.addresses) {
      if (addr.isLoopback) continue;
      if (_isTunnelInterface(interface.name)) {
        vpnIp ??= addr.address;
      } else {
        lanIp ??= addr.address;
      }
      break;
    }
  }
  return NetworkAddresses(lanIp: lanIp, vpnIp: vpnIp);
}

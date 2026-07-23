import 'dart:io';

/// This device's LAN IPv4 address (first non-loopback interface), or null if
/// none is found. Used to show LAN peers where to point their proxy client.
Future<String?> currentLanIp() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: false,
  );
  for (final interface in interfaces) {
    for (final addr in interface.addresses) {
      if (!addr.isLoopback) return addr.address;
    }
  }
  return null;
}

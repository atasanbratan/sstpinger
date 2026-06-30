class VpnServer {
  final int id;
  final String hostname;
  final String ip;
  final int port;
  final String key;
  final int sessions;
  final String info;
  final String info2;
  final String country;
  final String countryShort;
  final String locationName;
  int? ping;

  VpnServer({
    required this.id,
    required this.hostname,
    required this.ip,
    required this.port,
    required this.key,
    required this.sessions,
    required this.info,
    required this.info2,
    required this.country,
    required this.countryShort,
    required this.locationName,
    this.ping,
  });

  factory VpnServer.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    return VpnServer(
      id: json['id'] as int? ?? 0,
      hostname: json['hostname'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      port: json['port'] as int? ?? 443,
      key: json['key'] as String? ?? '',
      sessions: json['sessions'] as int? ?? 0,
      info: json['info'] as String? ?? '',
      info2: json['info2'] as String? ?? '',
      country: loc['country'] as String? ?? '',
      countryShort: loc['short'] as String? ?? '',
      locationName: loc['name'] as String? ?? '',
    );
  }
}

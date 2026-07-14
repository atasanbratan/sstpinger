import '../../domain/entities/vpn_server.dart';

/// JSON <-> [VpnServer] mapping, kept out of the entity so the domain stays free
/// of persistence concerns. Both directions live here because the local cache
/// persists servers as JSON in the same shape the backend returns them.
class VpnServerDto {
  const VpnServerDto._();

  static VpnServer fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? const {};
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
      ping: json['ping'] as int?,
    );
  }

  static Map<String, dynamic> toJson(VpnServer server) {
    return {
      'id': server.id,
      'hostname': server.hostname,
      'ip': server.ip,
      'port': server.port,
      'key': server.key,
      'sessions': server.sessions,
      'info': server.info,
      'info2': server.info2,
      'location': {
        'country': server.country,
        'short': server.countryShort,
        'name': server.locationName,
      },
      if (server.ping != null) 'ping': server.ping,
    };
  }

  static List<VpnServer> listFromJson(List<dynamic> list) =>
      list.map((e) => fromJson(e as Map<String, dynamic>)).toList();

  static List<Map<String, dynamic>> listToJson(List<VpnServer> servers) =>
      servers.map(toJson).toList();
}

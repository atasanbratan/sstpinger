import '../../domain/entities/vpn_server.dart';

/// JSON <-> [VpnServer] mapping, kept out of the entity so the domain stays free
/// of persistence concerns. Both directions live here because the local cache
/// persists servers as JSON in the same shape the backend returns them.
class VpnServerDto {
  const VpnServerDto._();

  static VpnServer fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? const {};
    return VpnServer(
      id: _asInt(json['id']) ?? 0,
      hostname: json['hostname'] as String? ?? '',
      ip: json['ip'] as String? ?? '',
      port: _asInt(json['port']) ?? 443,
      key: json['key'] as String? ?? '',
      sessions: _asInt(json['sessions']) ?? 0,
      info: json['info'] as String? ?? '',
      info2: json['info2'] as String? ?? '',
      country: loc['country'] as String? ?? '',
      countryShort: loc['short'] as String? ?? '',
      locationName: loc['name'] as String? ?? '',
      ping: _asInt(json['ping']),
    );
  }

  /// The backend stores sheet cells untyped, so a numeric field can arrive as
  /// `""` (blank cell) or a numeric string instead of an `int`/`null` — a
  /// plain `as int?` cast throws in that case rather than falling back.
  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
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

  /// Parses each entry independently so one malformed server (e.g. an
  /// unparsable field from a manually-edited sheet row) doesn't discard the
  /// whole fetched list.
  static List<VpnServer> listFromJson(List<dynamic> list) {
    final servers = <VpnServer>[];
    for (final e in list) {
      try {
        servers.add(fromJson(e as Map<String, dynamic>));
      } catch (_) {
        continue;
      }
    }
    return servers;
  }

  static List<Map<String, dynamic>> listToJson(List<VpnServer> servers) =>
      servers.map(toJson).toList();
}

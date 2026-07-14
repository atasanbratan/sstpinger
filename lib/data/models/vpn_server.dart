import 'package:equatable/equatable.dart';

class VpnServer extends Equatable {
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
  final int? ping;

  const VpnServer({
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

  /// Stable identity used for bookmarks and ping matching across refetches
  /// (the backend `id` can change, but the endpoint stays put).
  String get endpoint => '$ip:$port';

  VpnServer copyWith({int? ping}) {
    return VpnServer(
      id: id,
      hostname: hostname,
      ip: ip,
      port: port,
      key: key,
      sessions: sessions,
      info: info,
      info2: info2,
      country: country,
      countryShort: countryShort,
      locationName: locationName,
      ping: ping ?? this.ping,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostname': hostname,
      'ip': ip,
      'port': port,
      'key': key,
      'sessions': sessions,
      'info': info,
      'info2': info2,
      'location': {
        'country': country,
        'short': countryShort,
        'name': locationName,
      },
      if (ping != null) 'ping': ping,
    };
  }

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
      ping: json['ping'] as int?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        hostname,
        ip,
        port,
        key,
        sessions,
        info,
        info2,
        country,
        countryShort,
        locationName,
        ping,
      ];
}

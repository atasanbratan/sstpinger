import 'package:equatable/equatable.dart';

/// A VPN server the user can connect to. A pure domain entity — it knows nothing
/// about JSON or persistence (that lives in `data/dto/vpn_server_dto.dart`).
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

  /// Round-trip latency in ms from the last probe, or null if never pinged /
  /// unreachable.
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

  /// A copy with [ping] set to exactly this value — **including null**, which
  /// means "the latest probe could not reach it".
  ///
  /// [copyWith] cannot express that: `ping ?? this.ping` treats null as "leave
  /// it alone", so a failed re-probe would silently keep a stale latency from an
  /// earlier sweep. Any code applying a fresh ping result must use this.
  VpnServer withPing(int? ping) => VpnServer(
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
    ping: ping,
  );

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

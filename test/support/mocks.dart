import 'package:mocktail/mocktail.dart';
import 'package:sstp_shield/domain/entities/tunnel_config.dart';
import 'package:sstp_shield/domain/entities/tunnel_protocol.dart';
import 'package:sstp_shield/domain/entities/vpn_server.dart';
import 'package:sstp_shield/domain/repositories/ping_service.dart';
import 'package:sstp_shield/domain/repositories/settings_repository.dart';
import 'package:sstp_shield/domain/repositories/subscription_repository.dart';
import 'package:sstp_shield/domain/repositories/tunnel_controller.dart';
import 'package:sstp_shield/domain/repositories/vpn_server_repository.dart';

class MockVpnServerRepository extends Mock implements VpnServerRepository {}

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockPingService extends Mock implements PingService {}

class MockTunnelController extends Mock implements TunnelController {}

/// A test server with sensible defaults; override only what a test cares about.
VpnServer server({
  int id = 1,
  String ip = '1.1.1.1',
  int port = 443,
  String country = 'Testland',
  String hostname = 'node.test',
  int? ping,
}) => VpnServer(
  id: id,
  hostname: hostname,
  ip: ip,
  port: port,
  key: 'k',
  sessions: 0,
  info: '',
  info2: '',
  country: country,
  countryShort: 'TL',
  locationName: country,
  ping: ping,
);

/// Registers fallback values for types used with mocktail's `any()`.
void registerFallbacks() {
  registerFallbackValue(
    const TunnelConfig(
      host: 'h',
      port: 443,
      username: 'u',
      password: 'p',
      label: 'l',
    ),
  );
  registerFallbackValue(<VpnServer>[]);
  registerFallbackValue(server());
  registerFallbackValue(TunnelProtocol.sstp);
}

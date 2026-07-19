import '../../data/datasources/preferences_data_source.dart';
import '../../data/datasources/tcp_ping_service.dart';
import '../../data/datasources/tls_ping_service.dart';
import '../../data/datasources/vpn_remote_data_source.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../data/repositories/tunnel_controller_impl.dart';
import '../../data/repositories/vpn_server_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/repositories/tunnel_controller.dart';
import '../../domain/repositories/vpn_server_repository.dart';
import '../../domain/usecases/connect_tunnel.dart';
import '../../domain/usecases/disconnect_tunnel.dart';
import '../../domain/usecases/fetch_servers.dart';
import '../../domain/usecases/import_activation.dart';
import '../../domain/usecases/load_cached_servers.dart';
import '../../domain/usecases/ping_servers.dart';
import '../../domain/usecases/refresh_servers.dart';
import '../../domain/usecases/start_free_trial.dart';
import '../../domain/usecases/subscribe_with_crypto.dart';
import '../../domain/usecases/watch_tunnel.dart';
import '../../presentation/bloc/connection/connection_bloc.dart';
import '../../presentation/bloc/vpn/vpn_bloc.dart';

/// The composition root. Wires the object graph — data sources, repositories,
/// use cases — once, and builds the two blocs from it. Held for the app's
/// lifetime by the root widget, which disposes [tunnel] on teardown.
class AppDependencies {
  final TunnelController tunnel;
  final VpnServerRepository serverRepository;
  final SubscriptionRepository subscriptionRepository;
  final SettingsRepository settingsRepository;
  final TcpPingService pingService;

  AppDependencies._({
    required this.tunnel,
    required this.serverRepository,
    required this.subscriptionRepository,
    required this.settingsRepository,
    required this.pingService,
  });

  /// [serverPool] is the backend pool this build fetches from (see
  /// [AppVariant.serverPool]) — null for the default full list.
  factory AppDependencies.create({String? serverPool}) {
    // Data sources (shared): one preferences store backs the server,
    // subscription and settings repositories.
    final prefs = PreferencesDataSource();
    final remote = VpnRemoteDataSource(pool: serverPool);

    return AppDependencies._(
      tunnel: TunnelControllerImpl.forPlatform(),
      serverRepository: VpnServerRepositoryImpl(remote, prefs),
      subscriptionRepository: SubscriptionRepositoryImpl(remote, prefs),
      settingsRepository: SettingsRepositoryImpl(prefs),
      pingService: const TcpPingService(),
    );
  }

  ConnectionBloc buildConnectionBloc() => ConnectionBloc(
    connect: ConnectTunnel(tunnel),
    disconnect: DisconnectTunnel(tunnel),
    watch: WatchTunnel(tunnel),
    settings: settingsRepository,
  );

  VpnBloc buildVpnBloc() => VpnBloc(
    fetchServers: FetchServers(serverRepository),
    refreshServers: RefreshServers(serverRepository),
    loadCached: LoadCachedServers(serverRepository),
    pingServers: PingServers(pingService, const TlsPingService()),
    importActivation: ImportActivation(subscriptionRepository, serverRepository),
    startFreeTrial: StartFreeTrial(subscriptionRepository, serverRepository),
    subscribeWithCrypto:
        SubscribeWithCrypto(subscriptionRepository, serverRepository),
    serverRepository: serverRepository,
    subscriptionRepository: subscriptionRepository,
    settingsRepository: settingsRepository,
  );

  void dispose() => tunnel.dispose();
}

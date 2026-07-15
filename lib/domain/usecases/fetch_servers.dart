import '../entities/vpn_server.dart';
import '../repositories/vpn_server_repository.dart';

/// Fetches the server list from the backend for the stored identity and caches
/// it. Throws `SubscriptionExpiredException` / `ApiException` on backend errors.
class FetchServers {
  final VpnServerRepository _repository;

  const FetchServers(this._repository);

  Future<List<VpnServer>> call() => _repository.fetchServers();
}

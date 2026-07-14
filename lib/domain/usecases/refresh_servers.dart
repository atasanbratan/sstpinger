import '../entities/vpn_server.dart';
import '../repositories/vpn_server_repository.dart';

/// Fetches the latest server list and merges it with the cache, keeping servers
/// the backend has dropped. Used for the background refresh after connecting.
class RefreshServers {
  final VpnServerRepository _repository;

  const RefreshServers(this._repository);

  Future<List<VpnServer>> call() => _repository.refreshAndMerge();
}

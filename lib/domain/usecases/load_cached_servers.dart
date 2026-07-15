import '../entities/vpn_server.dart';
import '../repositories/vpn_server_repository.dart';

/// Loads the persisted server list (with saved ping values), for showing
/// something before the first network fetch completes.
class LoadCachedServers {
  final VpnServerRepository _repository;

  const LoadCachedServers(this._repository);

  Future<List<VpnServer>> call() => _repository.loadCached();
}

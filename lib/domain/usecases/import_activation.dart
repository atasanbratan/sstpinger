import '../entities/vpn_server.dart';
import '../repositories/subscription_repository.dart';
import '../repositories/vpn_server_repository.dart';

/// Imports a base64 activation code: the subscription repository decodes it and
/// persists the username; this use case then caches the servers it unlocked.
/// Keeping the two-repository coordination here is why the subscription
/// repository doesn't write the server cache itself.
class ImportActivation {
  final SubscriptionRepository _subscriptions;
  final VpnServerRepository _servers;

  const ImportActivation(this._subscriptions, this._servers);

  Future<List<VpnServer>> call(String base64) async {
    final unlocked = await _subscriptions.importActivationCode(base64);
    await _servers.saveWithPing(unlocked);
    return unlocked;
  }
}

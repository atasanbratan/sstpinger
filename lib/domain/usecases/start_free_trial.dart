import '../entities/vpn_server.dart';
import '../repositories/subscription_repository.dart';
import '../repositories/vpn_server_repository.dart';

/// Foreign variant: starts the one-time free trial and caches the servers the
/// resulting activation unlocked.
class StartFreeTrial {
  final SubscriptionRepository _subscriptions;
  final VpnServerRepository _servers;

  const StartFreeTrial(this._subscriptions, this._servers);

  Future<List<VpnServer>> call() async {
    final unlocked = await _subscriptions.startFreeTrial();
    await _servers.saveWithPing(unlocked);
    return unlocked;
  }
}

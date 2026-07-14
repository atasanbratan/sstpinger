import '../entities/vpn_server.dart';
import '../repositories/subscription_repository.dart';
import '../repositories/vpn_server_repository.dart';

/// Foreign variant: verifies a crypto payment on the backend and caches the
/// servers the resulting activation unlocked.
class SubscribeWithCrypto {
  final SubscriptionRepository _subscriptions;
  final VpnServerRepository _servers;

  const SubscribeWithCrypto(this._subscriptions, this._servers);

  Future<List<VpnServer>> call({
    required String network,
    required String txHash,
  }) async {
    final unlocked = await _subscriptions.subscribeWithCrypto(
      network: network,
      txHash: txHash,
    );
    await _servers.saveWithPing(unlocked);
    return unlocked;
  }
}

import '../entities/subscription.dart';
import '../entities/vpn_server.dart';

/// Contract for identity (username/device id), activation, and the subscription
/// window. Activation blobs carry both the username and a server list, so these
/// methods return the servers they unlocked; the caller persists them via
/// [VpnServerRepository]. The implementation shares a local data source with the
/// server repository, so that coupling stays in `data/`.
abstract class SubscriptionRepository {
  Future<String> getUsername();

  Future<void> saveUsername(String username);

  Future<String> getOrCreateDeviceId();

  /// Loads the persisted subscription window (expiry + last fetch time).
  Future<Subscription> loadSubscription();

  /// Decodes a base64 activation blob, persists the username it carries, and
  /// returns the server list it unlocked.
  Future<List<VpnServer>> importActivationCode(String base64);

  /// Foreign variant: starts the one-time free trial and imports the resulting
  /// activation blob. Returns the unlocked servers.
  Future<List<VpnServer>> startFreeTrial();

  /// Foreign variant: verifies a crypto payment on the backend and imports the
  /// resulting activation blob. Returns the unlocked servers.
  Future<List<VpnServer>> subscribeWithCrypto({
    required String network,
    required String txHash,
  });
}

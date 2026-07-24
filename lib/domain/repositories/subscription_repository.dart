import '../entities/auth_session.dart';
import '../entities/subscription.dart';
import '../entities/user_session.dart';
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

  // ---- Google Sign-In + sessions ----

  /// Whether interactive Google Sign-In is available on this platform and
  /// configured (server client id present). Desktop falls back to codes/USDT.
  bool get isGoogleSignInSupported;

  /// Whether a Google session token is currently stored (i.e. signed in).
  Future<bool> hasSession();

  /// The signed-in account email, or '' when not signed in.
  Future<String> getAccountEmail();

  /// Runs the interactive Google Sign-In, exchanges the ID token for a backend
  /// session, persists it, and returns the account's subscription window. Null
  /// if the user cancelled the sign-in.
  Future<AuthSession?> signInWithGoogle();

  /// Clears the local Google session (and revokes it on the backend if given a
  /// live session).
  Future<void> signOut();

  /// The signed-in account's registered device sessions.
  Future<List<UserSession>> listSessions();

  /// Revokes one of the account's own sessions by id.
  Future<void> revokeSession(int id);

  /// Whether the one-time "sign in to keep access" nudge has already been
  /// shown (it's offered at most once, after the first trial/subscription
  /// success while not signed in — see `VpnBloc._afterUnlock`).
  Future<bool> hasSeenGoogleLinkPrompt();

  /// Marks the nudge as shown, regardless of what the user chose.
  Future<void> markGoogleLinkPromptSeen();
}

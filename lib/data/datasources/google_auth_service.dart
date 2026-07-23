import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/backend_config.dart';

/// Thin wrapper over `google_sign_in` (7.x singleton API) that yields a Google
/// **ID token** for the backend to verify. Interactive sign-in is only available
/// on platforms the plugin supports (Android/iOS/macOS/web) — [isSupported]
/// reflects that; on Linux/Windows desktop it is false and callers fall back to
/// the activation-code / USDT paths.
class GoogleAuthService {
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  bool _initialized = false;

  /// Whether interactive Google Sign-In works on this platform *and* a server
  /// client id is configured (without it the ID token audience wouldn't match
  /// the backend).
  bool get isSupported =>
      BackendConfig.isGoogleConfigured && _signIn.supportsAuthenticate();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _signIn.initialize(
      serverClientId: BackendConfig.googleServerClientId,
    );
    _initialized = true;
  }

  /// Runs the interactive sign-in and returns a fresh Google ID token, or null
  /// if the user cancelled. Throws on a real failure (misconfiguration, network).
  Future<String?> signInIdToken() async {
    if (!isSupported) return null;
    await _ensureInitialized();
    try {
      final account = await _signIn.authenticate(scopeHint: const ['email']);
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Clears the local Google session (does not revoke the backend session).
  Future<void> signOut() async {
    if (!_initialized) return;
    await _signIn.signOut();
  }
}

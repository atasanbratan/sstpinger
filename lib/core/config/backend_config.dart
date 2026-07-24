/// Backend endpoint + Google Sign-In configuration.
///
/// Both are compile-time constants supplied with `--dart-define` so the same
/// source builds against a dev/prod backend without code edits:
///
///   flutter build apk --target lib/main.dart \
///     --dart-define=API_BASE_URL=https://sstp-shield-server.vercel.app \
///     --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
///
/// The new backend is the Go service on Vercel (see ../../../sstp_shield_server),
/// which replaced the old Google Apps Script `/exec` endpoint.
class BackendConfig {
  BackendConfig._();

  /// Base URL of the Go/Vercel backend, no trailing slash.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sstp-shield-server.vercel.app',
  );

  /// The **Web** OAuth client ID used as `serverClientId` for Google Sign-In, so
  /// the returned ID token's audience matches what the backend accepts
  /// (GOOGLE_CLIENT_IDS). Empty disables Google Sign-In (falls back to the
  /// activation-code / USDT paths).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isGoogleConfigured => googleServerClientId.isNotEmpty;
}

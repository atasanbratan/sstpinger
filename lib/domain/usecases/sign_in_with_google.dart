import '../entities/auth_session.dart';
import '../repositories/subscription_repository.dart';

/// Runs the interactive Google Sign-In and establishes a backend session.
/// Returns the account's subscription window, or null if the user cancelled.
class SignInWithGoogle {
  final SubscriptionRepository _subs;

  const SignInWithGoogle(this._subs);

  Future<AuthSession?> call() => _subs.signInWithGoogle();
}

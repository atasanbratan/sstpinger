// Domain-level failures, carrying a message that is safe to show to the user.
//
// These are pure (no `dio`): the data layer maps transport errors like
// `DioException` into these before they cross into the domain, so the domain and
// presentation layers never depend on the HTTP client.

/// A network/API failure with a human-friendly message.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// The backend reported that the user's subscription has expired
/// (`SUBSCRIPTION_EXPIRED`). Callers should block connecting and send the user
/// back to onboarding.
class SubscriptionExpiredException implements Exception {
  final String message;
  const SubscriptionExpiredException([
    this.message = 'Your subscription has expired.',
  ]);

  @override
  String toString() => message;
}

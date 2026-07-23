import 'package:equatable/equatable.dart';

/// The result of a successful Google Sign-In: the signed-in account email and
/// the subscription expiry the backend reports for that account (which may be in
/// the past for a brand-new account that hasn't started a trial/subscription).
class AuthSession extends Equatable {
  final String email;
  final DateTime? expireTime;

  const AuthSession({required this.email, this.expireTime});

  @override
  List<Object?> get props => [email, expireTime];
}

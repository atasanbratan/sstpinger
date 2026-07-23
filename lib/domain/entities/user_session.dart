import 'package:equatable/equatable.dart';

/// One registered device session for the signed-in account. Replaces the old
/// fixed one-per-platform device slots: a user may hold several concurrent
/// sessions (up to the backend's cap) and revoke them individually.
class UserSession extends Equatable {
  final int id;
  final String deviceId;
  final String platform;
  final bool active;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  const UserSession({
    required this.id,
    required this.deviceId,
    required this.platform,
    required this.active,
    this.lastSeenAt,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, deviceId, platform, active, lastSeenAt, createdAt];
}

import '../../domain/entities/user_session.dart';

/// JSON <-> [UserSession] mapping for the backend's /api/sessions responses.
/// Field names mirror the Go `Session` json tags (id, deviceId, platform,
/// active, lastSeenAt, createdAt).
class UserSessionDto {
  static UserSession fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deviceId: json['deviceId']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      active: json['active'] as bool? ?? true,
      lastSeenAt: _parse(json['lastSeenAt']),
      createdAt: _parse(json['createdAt']),
    );
  }

  static List<UserSession> listFromJson(List<dynamic> json) => [
        for (final e in json)
          UserSessionDto.fromJson(e as Map<String, dynamic>),
      ];

  static DateTime? _parse(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }
}

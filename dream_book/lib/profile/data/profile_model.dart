/// Data model for the user profile, mirroring the `public.profile` table.
library;

class UserProfile {
  const UserProfile({required this.id, this.name});

  /// Matches auth.users.id — the profile is 1:1 with the auth user.
  final String id;

  /// Display name; null/empty until the user sets one.
  final String? name;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
    );
  }

  UserProfile copyWith({String? name}) =>
      UserProfile(id: id, name: name ?? this.name);
}

/// Model for user mention (search results).
/// Matches API response: { "data": [ { "id", "username", "name", "profileImage", ... } ], "pagination": { ... } }
class MentionUser {
  final String id;
  final String fullName;
  final String username;
  final String profileImageUrl;

  MentionUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.profileImageUrl,
  });

  /// From users/search response item: id, username, name, profileImage (nullable).
  factory MentionUser.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final username = json['username']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final profileImage = json['profileImage'];
    final profileImageUrl = profileImage is String ? profileImage : '';
    return MentionUser(
      id: id,
      fullName: name,
      username: username,
      profileImageUrl: profileImageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': fullName,
        'profileImage': profileImageUrl.isEmpty ? null : profileImageUrl,
      };
}

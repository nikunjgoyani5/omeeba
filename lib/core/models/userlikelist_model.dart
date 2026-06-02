class UserLikeListModel {
  bool success;
  String message;
  UserLikeData data;

  UserLikeListModel({
    required this.success,
    required this.message,
    required this.data,
  });

  factory UserLikeListModel.fromJson(Map<String, dynamic> json) {
    return UserLikeListModel(
      success: json['success'] ?? false,
      message: json['message']?.toString() ?? '',
      data: UserLikeData.fromJson(json['data'] ?? {}),
    );
  }
}

class UserLikeData {
  List<LikedUser> users;

  UserLikeData({
    required this.users,
  });

  factory UserLikeData.fromJson(Map<String, dynamic> json) {
    return UserLikeData(
      users: (json['users'] as List? ?? [])
          .map((e) => LikedUser.fromJson(e))
          .toList(),
    );
  }
}

class LikedUser {
  String id;
  String name;
  String username;
  String bio;
  String profileImage;
  String coverImage;
  bool isFollowing;
  bool isSelf;

  LikedUser({
    required this.id,
    required this.name,
    required this.username,
    required this.bio,
    required this.profileImage,
    required this.coverImage,
    required this.isFollowing,
    required this.isSelf,
  });

  factory LikedUser.fromJson(Map<String, dynamic> json) {
    return LikedUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      profileImage: json['profileImage']?.toString() ?? '',
      coverImage: json['coverImage']?.toString() ?? '',
      isFollowing: json['isFollowing'] ?? false,
      isSelf: json['isSelf'] ?? false,
    );
  }
}
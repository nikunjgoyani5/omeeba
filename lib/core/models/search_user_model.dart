/// Search user result from explore/search API (type=users).
class SearchUserData {
  final String? id;
  final String? name;
  final String? username;
  final dynamic profileImage;
  final String? bio;
  final bool? isAccountVerified;
  final bool? isVerifiedBadge;
  final int? followerCount;

  SearchUserData({
    this.id,
    this.name,
    this.username,
    this.profileImage,
    this.bio,
    this.isAccountVerified,
    this.isVerifiedBadge,
    this.followerCount,
  });

  factory SearchUserData.fromJson(Map<String, dynamic> json) => SearchUserData(
        id: json["id"]?.toString(),
        name: json["name"],
        username: json["username"],
        profileImage: json["profileImage"],
        bio: json["bio"],
        isAccountVerified: json["isAccountVerified"],
        isVerifiedBadge: json["isVerifiedBadge"],
        followerCount: json["followerCount"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "username": username,
        "profileImage": profileImage,
        "bio": bio,
        "isAccountVerified": isAccountVerified,
        "isVerifiedBadge": isVerifiedBadge,
        "followerCount": followerCount,
      };

  String? get profileImageUrl {
    if (profileImage is String && (profileImage as String).isNotEmpty) {
      return profileImage as String;
    }
    return null;
  }
}

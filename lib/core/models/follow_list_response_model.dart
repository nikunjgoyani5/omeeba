import 'api_response.dart';

/// Response for GET follow/following and GET follow/followers.
/// Same structure as other list responses; uses common [Pagination].
class FollowListResponseModel {
  bool? success;
  String? message;
  List<FollowListItem>? data;
  Pagination? pagination;

  FollowListResponseModel({this.success, this.message, this.data, this.pagination});

  factory FollowListResponseModel.fromJson(Map<String, dynamic> json) => FollowListResponseModel(
        success: json["success"],
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<FollowListItem>.from(json["data"]!.map((x) => FollowListItem.fromJson(x))),
        pagination: json["pagination"] == null ? null : Pagination.fromJson(json["pagination"]),
      );

  Map<String, dynamic> toJson() => {
        "success": success,
        "message": message,
        "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
        "pagination": pagination?.toJson(),
      };
}

class FollowListItem {
  String? id;
  String? username;
  String? name;
  String? profileImage;
  String? bio;
  bool? isVerifiedBadge;
  String? followedAt;
  String? status; // e.g. "following", "not_following"

  FollowListItem({
    this.id,
    this.username,
    this.name,
    this.profileImage,
    this.bio,
    this.isVerifiedBadge,
    this.followedAt,
    this.status,
  });

  factory FollowListItem.fromJson(Map<String, dynamic> json) => FollowListItem(
        id: json["id"]?.toString(),
        username: json["username"]?.toString(),
        name: json["name"],
        profileImage: json["profileImage"]?.toString(),
        bio: json["bio"]?.toString(),
        isVerifiedBadge: json["isVerifiedBadge"],
        followedAt: json["followedAt"]?.toString(),
        status: json["status"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "username": username,
        "name": name,
        "profileImage": profileImage,
        "bio": bio,
        "isVerifiedBadge": isVerifiedBadge,
        "followedAt": followedAt,
        "status": status,
      };

  bool get isFollowing => (status ?? '').toLowerCase() == 'following';

  /// True when this list item is the current login user (no Follow/Following action).
  bool get isSelf => (status ?? '').toLowerCase() == 'self';

  FollowListItem copyWith({
    String? id,
    String? username,
    String? name,
    String? profileImage,
    String? bio,
    bool? isVerifiedBadge,
    String? followedAt,
    String? status,
  }) =>
      FollowListItem(
        id: id ?? this.id,
        username: username ?? this.username,
        name: name ?? this.name,
        profileImage: profileImage ?? this.profileImage,
        bio: bio ?? this.bio,
        isVerifiedBadge: isVerifiedBadge ?? this.isVerifiedBadge,
        followedAt: followedAt ?? this.followedAt,
        status: status ?? this.status,
      );
}

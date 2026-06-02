// To parse this JSON data, do
//
//     final userProfileResponseModel = userProfileResponseModelFromJson(jsonString);

import 'dart:convert';

UserProfileResponseModel userProfileResponseModelFromJson(String str) =>
    UserProfileResponseModel.fromJson(json.decode(str));

String userProfileResponseModelToJson(UserProfileResponseModel data) => json.encode(data.toJson());

class UserProfileResponseModel {
  bool? success;
  String? message;
  ProfileData? data;

  UserProfileResponseModel({this.success, this.message, this.data});

  factory UserProfileResponseModel.fromJson(Map<String, dynamic> json) => UserProfileResponseModel(
    success: json["success"],
    message: json["message"],
    data: json["data"] == null ? null : ProfileData.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {"success": success, "message": message, "data": data?.toJson()};
}

class ProfileData {
  Profile? profile;

  ProfileData({this.profile});

  factory ProfileData.fromJson(Map<String, dynamic> json) =>
      ProfileData(profile: json["profile"] == null ? null : Profile.fromJson(json["profile"]));

  Map<String, dynamic> toJson() => {"profile": profile?.toJson()};
}

class Profile {
  String? id;
  String? name;
  String? username;
  dynamic profileImage;
  dynamic coverImage;
  String? bio;
  bool? isVerifiedBadge;
  bool? isAccountVerified;
  int? followersCount;
  int? followingCount;
  ContentCounts? contentCounts;
  dynamic followStatus;
  DateTime? createdAt;
  DateTime? updatedAt;

  Profile({
    this.id,
    this.name,
    this.username,
    this.profileImage,
    this.coverImage,
    this.bio,
    this.isVerifiedBadge,
    this.isAccountVerified,
    this.followersCount,
    this.followingCount,
    this.contentCounts,
    this.followStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json["id"],
    name: json["name"],
    username: json["username"],
    profileImage: json["profileImage"],
    coverImage: json["coverImage"],
    bio: json["bio"],
    isVerifiedBadge: json["isVerifiedBadge"],
    isAccountVerified: json["isAccountVerified"],
    followersCount: json["followersCount"],
    followingCount: json["followingCount"],
    contentCounts: json["contentCounts"] == null ? null : ContentCounts.fromJson(json["contentCounts"]),
    followStatus: json["followStatus"],
    createdAt: json["createdAt"] == null ? null : DateTime.parse(json["createdAt"]),
    updatedAt: json["updatedAt"] == null ? null : DateTime.parse(json["updatedAt"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "username": username,
    "profileImage": profileImage,
    "coverImage": coverImage,
    "bio": bio,
    "isVerifiedBadge": isVerifiedBadge,
    "isAccountVerified": isAccountVerified,
    "followersCount": followersCount,
    "followingCount": followingCount,
    "contentCounts": contentCounts?.toJson(),
    "followStatus": followStatus,
    "createdAt": createdAt?.toIso8601String(),
    "updatedAt": updatedAt?.toIso8601String(),
  };
}

class ContentCounts {
  int? posts;
  int? writePosts;
  int? zealPosts;
  int? polls;
  int? total;

  ContentCounts({this.posts, this.writePosts, this.zealPosts, this.polls, this.total});

  factory ContentCounts.fromJson(Map<String, dynamic> json) => ContentCounts(
    posts: json["posts"],
    writePosts: json["writePosts"],
    zealPosts: json["zealPosts"],
    polls: json["polls"],
    total: json["total"],
  );

  Map<String, dynamic> toJson() => {
    "posts": posts,
    "writePosts": writePosts,
    "zealPosts": zealPosts,
    "polls": polls,
    "total": total,
  };
}

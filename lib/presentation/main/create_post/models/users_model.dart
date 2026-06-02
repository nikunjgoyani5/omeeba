// To parse this JSON data, do
//
//     final userSearchModel = userSearchModelFromJson(jsonString);

import 'dart:convert';

UserSearchModel userSearchModelFromJson(String str) => UserSearchModel.fromJson(json.decode(str));

String userSearchModelToJson(UserSearchModel data) => json.encode(data.toJson());

class UserSearchModel {
  bool? success;
  String? message;
  List<UserData>? data;
  Pagination? pagination;

  UserSearchModel({
    this.success,
    this.message,
    this.data,
    this.pagination,
  });

  factory UserSearchModel.fromJson(Map<String, dynamic> json) => UserSearchModel(
    success: json["success"],
    message: json["message"],
    data: json["data"] == null ? [] : List<UserData>.from(json["data"]!.map((x) => UserData.fromJson(x))),
    pagination: json["pagination"] == null ? null : Pagination.fromJson(json["pagination"]),
  );

  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

class UserData {
  String? id;
  String? username;
  String? name;
  String? profileImage;
  String? bio;
  bool? isVerifiedBadge;
  int? followerCount;
  int? followingCount;
  String? status;

  UserData({
    this.id,
    this.username,
    this.name,
    this.profileImage,
    this.bio,
    this.isVerifiedBadge,
    this.followerCount,
    this.followingCount,
    this.status,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
    id: json["id"],
    username: json["username"],
    name: json["name"],
    profileImage: json["profileImage"],
    bio: json["bio"],
    isVerifiedBadge: json["isVerifiedBadge"],
    followerCount: json["followerCount"],
    followingCount: json["followingCount"],
    status: json["status"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "username": username,
    "name": name,
    "profileImage": profileImage,
    "bio": bio,
    "isVerifiedBadge": isVerifiedBadge,
    "followerCount": followerCount,
    "followingCount": followingCount,
    "status": status,
  };
}

class Pagination {
  int? page;
  int? limit;
  int? total;
  int? pages;
  bool? hasNext;
  bool? hasPrev;

  Pagination({
    this.page,
    this.limit,
    this.total,
    this.pages,
    this.hasNext,
    this.hasPrev,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    page: json["page"],
    limit: json["limit"],
    total: json["total"],
    pages: json["pages"],
    hasNext: json["hasNext"],
    hasPrev: json["hasPrev"],
  );

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "total": total,
    "pages": pages,
    "hasNext": hasNext,
    "hasPrev": hasPrev,
  };
}

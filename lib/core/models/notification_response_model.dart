// To parse this JSON data, do
//
//     final welcome = welcomeFromJson(jsonString);

import 'dart:convert';

import 'api_response.dart';

NotificationResponseModel welcomeFromJson(String str) =>
    NotificationResponseModel.fromJson(json.decode(str));

String welcomeToJson(NotificationResponseModel data) =>
    json.encode(data.toJson());

class NotificationResponseModel {
  bool? success;
  String? message;
  List<NotificationData>? data;
  Pagination? pagination;

  NotificationResponseModel({
    this.success,
    this.message,
    this.data,
    this.pagination,
  });

  factory NotificationResponseModel.fromJson(Map<String, dynamic> json) =>
      NotificationResponseModel(
        success: json["success"],
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<NotificationData>.from(
                json["data"]!.map((x) => NotificationData.fromJson(x)),
              ),
        pagination: json["pagination"] == null
            ? null
            : Pagination.fromJson(json["pagination"]),
      );

  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data == null
        ? []
        : List<dynamic>.from(data!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

class NotificationData {
  String? id;
  String? type;
  String? message;
  String? status;
  String? contentType;
  String? contentId;
  Content? content;
  Sender? sender;
  bool? isAggregated;
  bool? isFollowingSender;
  int? aggregatedCount;
  List<Sender>? aggregatedUsers;
  Metadata? metadata;
  String? imageUrl;
  DateTime? createdAt;
  DateTime? updatedAt;
  NotificationData({
    this.id,
    this.type,
    this.message,
    this.status,
    this.contentType,
    this.contentId,
    this.content,
    this.sender,
    this.isAggregated,
    this.aggregatedCount,
    this.aggregatedUsers,
    this.metadata,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.isFollowingSender,
  });

  NotificationData copyWith({
    String? id,
    String? type,
    String? message,
    String? status,
    String? contentType,
    String? contentId,
    Content? content,
    Sender? sender,
    bool? isAggregated,
    bool? isFollowingSender,
    int? aggregatedCount,
    List<Sender>? aggregatedUsers,
    Metadata? metadata,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NotificationData(
    id: id ?? this.id,
    type: type ?? this.type,
    message: message ?? this.message,
    status: status ?? this.status,
    contentType: contentType ?? this.contentType,
    contentId: contentId ?? this.contentId,
    content: content ?? this.content,
    sender: sender ?? this.sender,
    isAggregated: isAggregated ?? this.isAggregated,
    aggregatedCount: aggregatedCount ?? this.aggregatedCount,
    aggregatedUsers: aggregatedUsers ?? this.aggregatedUsers,
    metadata: metadata ?? this.metadata,
    imageUrl: imageUrl ?? this.imageUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isFollowingSender: isFollowingSender??this.isFollowingSender,
  );

  factory NotificationData.fromJson(Map<String, dynamic> json) =>
      NotificationData(
        id: json["id"],
        type: json["type"],
        message: json["message"],
        status: json["status"],
        contentType: json["contentType"],
        contentId: json["contentId"],
        content: json["content"] == null
            ? null
            : Content.fromJson(json["content"]),
        sender: json["sender"] == null ? null : Sender.fromJson(json["sender"]),
        isAggregated: json["isAggregated"],
        aggregatedCount: json["aggregatedCount"],
        aggregatedUsers: json["aggregatedUsers"] == null
            ? []
            : List<Sender>.from(
                json["aggregatedUsers"]!.map((x) => Sender.fromJson(x)),
              ),
        metadata: json["metadata"] == null
            ? null
            : Metadata.fromJson(json["metadata"]),
        imageUrl: json["imageUrl"],
        createdAt: json["createdAt"] == null
            ? null
            : DateTime.parse(json["createdAt"]),
        updatedAt: json["updatedAt"] == null
            ? null
            : DateTime.parse(json["updatedAt"]),
        isFollowingSender: json['isFollowingSender'],
      );

  Map<String, dynamic> toJson() => {
    "id": id,
    "type": type,
    "message": message,
    "status": status,
    "contentType": contentType,
    "contentId": contentId,
    "sender": sender?.toJson(),
    "isAggregated": isAggregated,
    "aggregatedCount": aggregatedCount,
    "aggregatedUsers": aggregatedUsers == null
        ? []
        : List<dynamic>.from(aggregatedUsers!.map((x) => x.toJson())),
    "metadata": metadata?.toJson(),
    "createdAt": createdAt?.toIso8601String(),
    "updatedAt": updatedAt?.toIso8601String(),
  };
}

class Content {
  String? id;
  String? thumbnail;
  List<String>? images;
  List<String>? videos;

  Content({this.id, this.images, this.videos, this.thumbnail});

  factory Content.fromJson(Map<String, dynamic> json) => Content(
    id: json["_id"],
    thumbnail: json["thumbnail"],
    images: json["images"] == null
        ? []
        : List<String>.from(json["images"]!.map((x) => x)),
    videos: json["videos"] == null
        ? []
        : List<String>.from(json["videos"]!.map((x) => x)),
  );

  Map<String, dynamic> toJson() => {
    "_id": id,
    "thumbnail": thumbnail,
    "images": images == null ? [] : List<dynamic>.from(images!.map((x) => x)),
    "videos": videos == null ? [] : List<dynamic>.from(videos!.map((x) => x)),
  };
}

class Sender {
  String? id;
  String? name;
  String? username;
  String? profileImage;
  bool? isAccountVerified;
  bool? isVerifiedBadge;

  Sender({
    this.id,
    this.name,
    this.username,
    this.profileImage,
    this.isAccountVerified,
    this.isVerifiedBadge,
  });

  factory Sender.fromJson(Map<String, dynamic> json) => Sender(
    id: json["id"],
    name: json["name"],
    username: json["username"],
    profileImage: json["profileImage"],
    isAccountVerified: json["isAccountVerified"],
    isVerifiedBadge: json["isVerifiedBadge"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "username": username,
    "profileImage": profileImage,
    "isAccountVerified": isAccountVerified,
    "isVerifiedBadge": isVerifiedBadge,
  };
}

class Metadata {
  String? commentId;
  String? commentText;
  Metadata({this.commentId, this.commentText});

  factory Metadata.fromJson(Map<String, dynamic> json) =>
      Metadata(commentId: json["commentId"], commentText: json["commentText"]);

  Map<String, dynamic> toJson() => {"commentId": commentId};
}

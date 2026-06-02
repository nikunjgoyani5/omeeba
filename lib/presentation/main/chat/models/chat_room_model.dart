// To parse this JSON data, do
//
//     final chatRoomModel = chatRoomModelFromJson(jsonString);

import 'dart:convert';

ChatRoomModel chatRoomModelFromJson(String str) => ChatRoomModel.fromJson(json.decode(str));

String chatRoomModelToJson(ChatRoomModel data) => json.encode(data.toJson());

class ChatRoomModel {
  bool? success;
  String? message;
  Data? data;
  Pagination? pagination;

  ChatRoomModel({this.success, this.message, this.data, this.pagination});

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) => ChatRoomModel(
    success: json["success"],
    message: json["message"],
    data: json["data"] == null ? null : Data.fromJson(json["data"]),
    pagination: json["pagination"] == null ? null : Pagination.fromJson(json["pagination"]),
  );

  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data?.toJson(),
    "pagination": pagination?.toJson(),
  };
}

class Data {
  List<RoomData>? rooms;

  Data({this.rooms});

  factory Data.fromJson(Map<String, dynamic> json) =>
      Data(rooms: json["rooms"] == null ? [] : List<RoomData>.from(json["rooms"]!.map((x) => RoomData.fromJson(x))));

  Map<String, dynamic> toJson() => {"rooms": rooms == null ? [] : List<dynamic>.from(rooms!.map((x) => x.toJson()))};
}

class Pagination {
  int? page;
  int? limit;
  int? total;
  int? totalPages;
  bool? hasNext;
  bool? hasPrevious;

  Pagination({this.page, this.limit, this.total, this.totalPages, this.hasNext, this.hasPrevious});

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
    page: json["page"],
    limit: json["limit"],
    total: json["total"],
    totalPages: json["pages"],
    hasNext: json["hasNext"],
    hasPrevious: json["hasPrev"],
  );

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "total": total,
    "pages": totalPages,
    "hasNext": hasNext,
    "hasPrev": hasPrevious,
  };
}

class RoomData {
  String? id;
  String? roomId;
  String? chatType;
  OtherUser? otherUser;
  String? lastMessage;
  String? lastMessageType;
  String? lastMessageStatus;
  bool? lastMessageFromMe;
  String? lastMessageId;
  String? lastMessageAt;
  String? timestamp;
  String? timeAgo;
  int? unreadCount;
  bool? isBlocked;
  String? createdAt;
  String? updatedAt;
  String? lastMessageMediaUrl;

  RoomData({
    this.id,
    this.roomId,
    this.chatType,
    this.otherUser,
    this.lastMessageFromMe,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageId,
    this.lastMessageStatus,
    this.lastMessageAt,
    this.timestamp,
    this.timeAgo,
    this.unreadCount,
    this.isBlocked,
    this.createdAt,
    this.lastMessageMediaUrl,
    this.updatedAt,
  });

  factory RoomData.fromJson(Map<String, dynamic> json) => RoomData(
    id: json["id"],
    roomId: json["roomId"],
    lastMessageId: json["lastMessageId"],
    chatType: json["chatType"],
    otherUser: json["otherUser"] == null ? null : OtherUser.fromJson(json["otherUser"]),
    lastMessage: json["lastMessage"],
    lastMessageType: json["lastMessageType"],
    lastMessageFromMe: json["lastMessageFromMe"] ?? false,
    lastMessageStatus: json["lastMessageStatus"],
    lastMessageAt: json["lastMessageAt"],
    timestamp: json["timestamp"],
    timeAgo: json["timeAgo"],
    unreadCount: json["unreadCount"],
    isBlocked: json["isBlocked"],
    createdAt: json["createdAt"],
    updatedAt: json["updatedAt"],
    lastMessageMediaUrl: json["lastMessageMediaUrl"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "roomId": roomId,
    "lastMessageId": lastMessageId,
    "lastMessageMediaUrl": lastMessageMediaUrl,
    "chatType": chatType,
    "otherUser": otherUser?.toJson(),
    "lastMessage": lastMessage,
    "lastMessageType": lastMessageType,
    "lastMessageStatus": lastMessageStatus,
    "lastMessageAt": lastMessageAt,
    "timestamp": timestamp,
    "timeAgo": timeAgo,
    "unreadCount": unreadCount,
    "isBlocked": isBlocked,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "lastMessageFromMe": lastMessageFromMe,
  };
}

class OtherUser {
  String? id;
  String? name;
  String? username;
  dynamic profileImage;
  String? bio;
  bool? isVerifiedBadge;
  int? followersCount;

  OtherUser({
    this.id,
    this.name,
    this.username,
    this.profileImage,
    this.bio,
    this.isVerifiedBadge,
    this.followersCount,
  });

  factory OtherUser.fromJson(Map<String, dynamic> json) => OtherUser(
    id: json["id"],
    name: json["name"],
    username: json["username"],
    profileImage: json["profileImage"],
    bio: json["bio"],
    isVerifiedBadge: json["isVerifiedBadge"],
    followersCount: json["followersCount"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "username": username,
    "profileImage": profileImage,
    "bio": bio,
    "isVerifiedBadge": isVerifiedBadge,
    "followersCount": followersCount,
  };
}

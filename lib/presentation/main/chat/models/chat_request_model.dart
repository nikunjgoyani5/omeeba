// To parse this JSON data, do
//
//     final chatRequestModel = chatRequestModelFromJson(jsonString);

import 'dart:convert';

ChatRequestModel chatRequestModelFromJson(String str) => ChatRequestModel.fromJson(json.decode(str));

String chatRequestModelToJson(ChatRequestModel data) => json.encode(data.toJson());

class ChatRequestModel {
  bool? success;
  String? message;
  Data? data;
  Pagination? pagination;

  ChatRequestModel({
    this.success,
    this.message,
    this.data,
    this.pagination,
  });

  factory ChatRequestModel.fromJson(Map<String, dynamic> json) => ChatRequestModel(
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
  List<ChatRequest>? requests;

  Data({
    this.requests,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    requests: json["requests"] == null ? [] : List<ChatRequest>.from(json["requests"]!.map((x) => ChatRequest.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "requests": requests == null ? [] : List<dynamic>.from(requests!.map((x) => x.toJson())),
  };
}

class ChatRequest {
  String? id;
  String? roomId;
  String? chatType;
  FromUser? otherUser;
  String? lastMessage;
  String? lastMessageType;
  String? lastMessageAt;
  String? timestamp;
  int? unreadCount;
  String? createdAt;
  String? lastMessageStatus;
  bool? lastMessageFromMe;
  String? lastMessageId;
  String? updatedAt;
  String? lastMessageMediaUrl;


  ChatRequest({
    this.id,
    this.roomId,
    this.chatType,
    this.otherUser,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageAt,
    this.timestamp,
    this.unreadCount,
    this.createdAt,
    this.updatedAt,
    this.lastMessageId,
    this.lastMessageFromMe,
    this.lastMessageStatus,
    this.lastMessageMediaUrl,
  });

  factory ChatRequest.fromJson(Map<String, dynamic> json) => ChatRequest(
    id: json["id"],
    roomId: json["roomId"],
    chatType: json["chatType"],
    otherUser: json["otherUser"] == null ? null : FromUser.fromJson(json["otherUser"]),
    lastMessage: json["lastMessage"],
    lastMessageType: json["lastMessageType"],
    lastMessageAt: json["lastMessageAt"],
    timestamp: json["timestamp"],
    unreadCount: json["unreadCount"],
    createdAt: json["createdAt"],
    updatedAt: json["updatedAt"],
    lastMessageFromMe: json["lastMessageFromMe"],
    lastMessageStatus: json["lastMessageStatus"],
    lastMessageId: json["lastMessageId"],
    lastMessageMediaUrl: json["lastMessageMediaUrl"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "roomId": roomId,
    "chatType": chatType,
    "otherUser": otherUser?.toJson(),
    "lastMessage": lastMessage,
    "lastMessageType": lastMessageType,
    "lastMessageAt": lastMessageAt,
    "timestamp": timestamp,
    "unreadCount": unreadCount,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "lastMessageId": lastMessageId,
    "lastMessageFromMe": lastMessageFromMe,
    "lastMessageStatus": lastMessageStatus,
    "lastMessageMediaUrl": lastMessageMediaUrl,
  };
}

class FromUser {
  String? id;
  String? name;
  String? username;
  dynamic profileImage;
  String? bio;
  bool? isVerifiedBadge;
  int? followersCount;

  FromUser({
    this.id,
    this.name,
    this.username,
    this.profileImage,
    this.bio,
    this.isVerifiedBadge,
    this.followersCount,
  });

  factory FromUser.fromJson(Map<String, dynamic> json) => FromUser(
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

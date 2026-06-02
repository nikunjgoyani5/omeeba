import 'dart:convert';

MessageModel messageModelFromJson(String str) =>
    MessageModel.fromJson(json.decode(str));

String messageModelToJson(MessageModel data) => json.encode(data.toJson());

class MessageModel {
  bool? success;
  Data? data;

  MessageModel({required this.success, required this.data});

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      success: json["success"],
      data: json["data"] == null ? null : Data.fromJson(json["data"]),
    );
  }

  Map<String, dynamic> toJson() => {"success": success, "data": data?.toJson()};
}

class Data {
  List<MessageData>? messages;
  Pagination? pagination;

  Data({required this.messages, required this.pagination});

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      messages: json["messages"] == null
          ? []
          : List<MessageData>.from(
              json["messages"]!.map((x) => MessageData.fromJson(x)),
            ),
      pagination: json["pagination"] == null
          ? null
          : Pagination.fromJson(json["pagination"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "messages": messages?.map((x) => x.toJson()).toList(),
    "pagination": pagination?.toJson(),
  };
}

class MessageData {
  String? id;
  String? roomId;
  Sender? sender;
  Sender? contentCreator;
  String? messageType;
  String? message;
  dynamic mediaUrl;
  dynamic thumbnailUrl;
  dynamic contentId;
  dynamic contentType;
  dynamic contentData;
  String? status;
  String? statusDisplay;
  String? timestamp;
  String? timeAgo;
  String? createdAt;
  String? requestStatus;

  MessageData({
    required this.id,
    required this.roomId,
    required this.sender,
    required this.messageType,
    required this.message,
    this.mediaUrl,
    this.contentData,
    this.thumbnailUrl,
    this.contentId,
    this.contentType,
    this.status,
    this.statusDisplay,
    this.timestamp,
    this.timeAgo,
    this.createdAt,
    this.contentCreator,
    this.requestStatus,
  });

  factory MessageData.fromJson(Map<String, dynamic> json) {
    return MessageData(
      id: json["id"],
      roomId: json["roomId"],
      sender: json["sender"] == null ? null : Sender.fromJson(json["sender"]),
      contentCreator: json["contentCreator"] == null
          ? null
          : Sender.fromJson(json["contentCreator"]),
      messageType: json["messageType"],
      message: json["message"],
      mediaUrl: json["mediaUrl"],
      thumbnailUrl: json["thumbnailUrl"],
      contentId: json["contentId"],
      contentType: json["contentType"],
      contentData: json["contentData"],
      status: json["status"],
      statusDisplay: json["statusDisplay"],
      timestamp: json["timestamp"],
      timeAgo: json["timeAgo"],
      createdAt: json["createdAt"],
      requestStatus: json["requestStatus"],
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "roomId": roomId,
    "sender": sender?.toJson(),
    "messageType": messageType,
    "message": message,
    "mediaUrl": mediaUrl,
    "thumbnailUrl": thumbnailUrl,
    "contentId": contentId,
    "contentType": contentType,
    "contentData": contentData,
    "status": status,
    "statusDisplay": statusDisplay,
    "timestamp": timestamp,
    "timeAgo": timeAgo,
    "createdAt": createdAt,
    "requestStatus": requestStatus,
  };
}

class Sender {
  String? id;
  String? name;
  String? username;
  dynamic profileImage;
  String? bio;
  bool? isVerifiedBadge;

  Sender({
    required this.id,
    required this.name,
    required this.username,
    this.profileImage,
    this.bio,
    this.isVerifiedBadge,
  });

  factory Sender.fromJson(Map<String, dynamic> json) {
    return Sender(
      id: json["id"],
      name: json["name"],
      username: json["username"],
      profileImage: json["profileImage"],
      bio: json["bio"],
      isVerifiedBadge: json["isVerifiedBadge"],
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "username": username,
    "profileImage": profileImage,
    "bio": bio,
    "isVerifiedBadge": isVerifiedBadge,
  };
}

class Pagination {
  int? page;
  int? limit;
  int? total;
  int? totalPages;

  Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json["page"],
      limit: json["limit"],
      total: json["total"],
      totalPages: json["totalPages"],
    );
  }

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "total": total,
    "totalPages": totalPages,
  };
}

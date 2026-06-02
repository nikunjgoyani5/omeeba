class MessageListResponse {
  bool? success;
  MessageListData? data;

  MessageListResponse({
    this.success,
    this.data,
  });

  factory MessageListResponse.fromJson(Map<String, dynamic> json) {
    return MessageListResponse(
      success: json["success"],
      data: json["data"] == null ? null : MessageListData.fromJson(json["data"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "success": success,
    "data": data?.toJson(),
  };
}

class MessageListData {
  List<MessageItem>? messages;
  Pagination? pagination;

  MessageListData({
    this.messages,
    this.pagination,
  });

  factory MessageListData.fromJson(Map<String, dynamic> json) {
    return MessageListData(
      messages: json["messages"] == null 
          ? [] 
          : List<MessageItem>.from(json["messages"].map((x) => MessageItem.fromJson(x))),
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

class MessageItem {
  String? id;
  String? roomId;
  SenderInfo? sender;
  String? messageType;
  String? message;
  String? mediaUrl;
  String? thumbnailUrl;
  String? contentId;
  String? contentType;
  String? status;
  String? statusDisplay;
  String? timestamp;
  String? timeAgo;
  String? createdAt;

  MessageItem({
    this.id,
    this.roomId,
    this.sender,
    this.messageType,
    this.message,
    this.mediaUrl,
    this.thumbnailUrl,
    this.contentId,
    this.contentType,
    this.status,
    this.statusDisplay,
    this.timestamp,
    this.timeAgo,
    this.createdAt,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json["id"],
      roomId: json["roomId"],
      sender: json["sender"] == null ? null : SenderInfo.fromJson(json["sender"]),
      messageType: json["messageType"],
      message: json["message"],
      mediaUrl: json["mediaUrl"],
      thumbnailUrl: json["thumbnailUrl"],
      contentId: json["contentId"],
      contentType: json["contentType"],
      status: json["status"],
      statusDisplay: json["statusDisplay"],
      timestamp: json["timestamp"],
      timeAgo: json["timeAgo"],
      createdAt: json["createdAt"],
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
    "status": status,
    "statusDisplay": statusDisplay,
    "timestamp": timestamp,
    "timeAgo": timeAgo,
    "createdAt": createdAt,
  };
}

class SenderInfo {
  String? id;
  String? name;
  String? username;
  String? profileImage;
  String? bio;
  bool? isVerifiedBadge;

  SenderInfo({
    this.id,
    this.name,
    this.username,
    this.profileImage,
    this.bio,
    this.isVerifiedBadge,
  });

  factory SenderInfo.fromJson(Map<String, dynamic> json) {
    return SenderInfo(
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
  String? page;
  String? limit;
  int? total;
  int? totalPages;

  Pagination({
    this.page,
    this.limit,
    this.total,
    this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json["page"]?.toString(),
      limit: json["limit"]?.toString(),
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

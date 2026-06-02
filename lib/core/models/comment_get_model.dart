// To parse this JSON data, do
//
//     final commentGetModel = commentGetModelFromJson(jsonString);

import 'dart:convert';

CommentGetModel commentGetModelFromJson(String str) => CommentGetModel.fromJson(json.decode(str));

String commentGetModelToJson(CommentGetModel data) => json.encode(data.toJson());

class CommentGetModel {
  bool? success;
  String? message;
  List<CommentData>? data;
  Pagination? pagination;

  CommentGetModel({this.success, this.message, this.data, this.pagination});

  factory CommentGetModel.fromJson(Map<String, dynamic> json) => CommentGetModel(
    success: json["success"],
    message: json["message"],
    data: json["data"] == null ? [] : List<CommentData>.from(json["data"]!.map((x) => CommentData.fromJson(x))),
    pagination: json["pagination"] == null ? null : Pagination.fromJson(json["pagination"]),
  );

  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
    "pagination": pagination?.toJson(),
  };
}

class CommentData {
  String? id;
  String? contentType;
  String? contentId;
  String? comment;
  User? user;
  List<User>? mentionedUsers;
  int? likeCount;
  String? likeCountFormatted;
  bool? isLiked;
  int? replyCount;
  String? timeAgo;
  String? createdAt;
  String? updatedAt;
  bool? isPosting;
  bool? isViewReply;
  List<ReplyData>? replies;

  CommentData({
    this.id,
    this.contentType,
    this.contentId,
    this.comment,
    this.user,
    this.mentionedUsers,
    this.likeCount,
    this.likeCountFormatted,
    this.isLiked,
    this.replyCount,
    this.timeAgo,
    this.isPosting = false,
    this.isViewReply = false,
    this.createdAt,
    this.updatedAt,
    this.replies,

  });

  factory CommentData.fromJson(Map<String, dynamic> json) => CommentData(
    replies: json["replies"] == null ? [] : List<ReplyData>.from(json["replies"]!.map((x) => ReplyData.fromJson(x))),

    id: json["id"],
    contentType: json["contentType"],
    contentId: json["contentId"],
    comment: json["comment"],
    isPosting: json["isPosting"]?? false,
    user: json["user"] == null ? null : User.fromJson(json["user"]),
    mentionedUsers: json["mentionedUsers"] == null ? [] : List<User>.from(json["mentionedUsers"]!.map((x) => User.fromJson(x))),
    likeCount: json["likeCount"],
    likeCountFormatted: json["likeCountFormatted"],
    isLiked: json["isLiked"],
    replyCount: json["replyCount"],
    timeAgo: json["timeAgo"],
    createdAt: json["createdAt"],
    updatedAt: json["updatedAt"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "replies": replies == null ? [] : List<dynamic>.from(replies!.map((x) => x.toJson())),

    "contentType": contentType,
    "contentId": contentId,
    "comment": comment,
    "user": user?.toJson(),
    "mentionedUsers": mentionedUsers == null ? [] : List<dynamic>.from(mentionedUsers!.map((x) => x.toJson())),
    "likeCount": likeCount,
    "likeCountFormatted": likeCountFormatted,
    "isLiked": isLiked,
    "replyCount": replyCount,
    "timeAgo": timeAgo,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
    "isPosting": isPosting,
  };
}

class User {
  String? id;
  String? name;
  String? username;
  String? profileImage;
  String? bio;
  bool? isVerifiedBadge;

  User({this.id, this.name, this.username, this.profileImage, this.bio, this.isVerifiedBadge});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"],
    name: json["name"],
    username: json["username"],
    profileImage: json["profileImage"],
    bio: json["bio"],
    isVerifiedBadge: json["isVerifiedBadge"],
  );

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
  int? pages;
  bool? hasNext;
  bool? hasPrev;

  Pagination({this.page, this.limit, this.total, this.pages, this.hasNext, this.hasPrev});

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

class ReplyData {
  String? id;
  String? commentId;
  String? reply;
  User? user;
  List<User>? mentionedUsers;
  int? likeCount;
  String? likeCountFormatted;
  bool? isLiked;
  String? timeAgo;
  String? createdAt;
  String? updatedAt;

  ReplyData({
    this.id,
    this.commentId,
    this.reply,
    this.user,
    this.mentionedUsers,
    this.likeCount,
    this.likeCountFormatted,
    this.isLiked,
    this.timeAgo,
    this.createdAt,
    this.updatedAt,
  });

  factory ReplyData.fromJson(Map<String, dynamic> json) {
    List<User> mentioned = [];
    if (json["mentionedUsers"] != null && json["mentionedUsers"] is List) {
      for (final x in json["mentionedUsers"] as List) {
        if (x is Map<String, dynamic>) {
          mentioned.add(User.fromJson(x));
        } else if (x is Map) {
          mentioned.add(User.fromJson(Map<String, dynamic>.from(x)));
        }
      }
    }
    return ReplyData(
      id: json["id"],
      commentId: json["commentId"],
      reply: json["reply"],
      user: json["user"] == null ? null : User.fromJson(json["user"]),
      mentionedUsers: mentioned,
      likeCount: json["likeCount"],
      likeCountFormatted: json["likeCountFormatted"],
      isLiked: json["isLiked"],
      timeAgo: json["timeAgo"],
      createdAt: json["createdAt"],
      updatedAt: json["updatedAt"],
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "commentId": commentId,
    "reply": reply,
    "user": user?.toJson(),
    "mentionedUsers": mentionedUsers == null ? [] : List<dynamic>.from(mentionedUsers!.map((x) => x.toJson())),
    "likeCount": likeCount,
    "likeCountFormatted": likeCountFormatted,
    "isLiked": isLiked,
    "timeAgo": timeAgo,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
  };
}
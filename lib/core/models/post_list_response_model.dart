// To parse this JSON data, do
//
//     final postListResponseModel = postListResponseModelFromJson(jsonString);

import 'dart:convert';

import 'api_response.dart';

PostListResponseModel postListResponseModelFromJson(String str) => PostListResponseModel.fromJson(json.decode(str));

String postListResponseModelToJson(PostListResponseModel data) => json.encode(data.toJson());

class PostListResponseModel {
  bool? success;
  String? message;
  PostDataResponse? data;
  Pagination? pagination;

  PostListResponseModel({this.success, this.message, this.data, this.pagination});

  factory PostListResponseModel.fromJson(Map<String, dynamic> json) => PostListResponseModel(
    success: json["success"],
    message: json["message"],
    data: json["data"] == null ? null : PostDataResponse.fromJson(json["data"]),
    pagination: json["pagination"] == null ? null : Pagination.fromJson(json["pagination"]),
  );

  Map<String, dynamic> toJson() => {
    "success": success,
    "message": message,
    "data": data?.toJson(),
    "pagination": pagination?.toJson(),
  };
}

class PostDataResponse {
  List<PostData>? posts;
  dynamic isFollowing;

  PostDataResponse({
    this.posts,
    this.isFollowing,
  });

  factory PostDataResponse.fromJson(Map<String, dynamic> json) => PostDataResponse(
    posts: json["posts"] == null ? [] : List<PostData>.from(json["posts"]!.map((x) => PostData.fromJson(Map<String, dynamic>.from(x as Map)))),
    isFollowing: json["isFollowing"],
  );

  Map<String, dynamic> toJson() => {
    "posts": posts == null ? [] : List<dynamic>.from(posts!.map((x) => x.toJson())),
    "isFollowing": isFollowing,
  };
}

/// Poll option from API (optionId, optionText, voteCount, votePercentage).
class PollOptionItem {
  String? optionId;
  String? optionText;
  int? voteCount;
  int? votePercentage;
  bool? selectedByAuthUser;

  PollOptionItem({this.optionId, this.optionText, this.voteCount, this.votePercentage, this.selectedByAuthUser});

  factory PollOptionItem.fromJson(Map<String, dynamic> json) => PollOptionItem(
    optionId: json["optionId"],
    optionText: json["optionText"],
    voteCount: json["voteCount"],
    votePercentage: json["votePercentage"],
    selectedByAuthUser: json['selectedByAuthUser'],
  );

  Map<String, dynamic> toJson() => {
    "optionId": optionId,
    "optionText": optionText,
    "voteCount": voteCount,
    "votePercentage": votePercentage,
    "selectedByAuthUser": selectedByAuthUser,
  };
}

class PostData {
  String? id;
  String? contentType;
  String? shareableLink;
  UserId? userId;
  List<UserId>? mentionedUsers;
  int? likeCount;
  int? commentCount;
  int? shareCount;
  bool? isLiked;
  bool? isSaved;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? caption;
  List<String>? images;
  List<String>? videos;
  /// Aspect ratio (width/height) of the first image when known (from API or resolved on load). Used for feed layout.
  double? imageAspectRatio;
  String? mediaUrl;
  /// Lower quality / smaller file URL when API provides multiple (adaptive by network).
  String? mediaUrlLow;
  /// Higher quality URL when API provides multiple (adaptive by network).
  String? mediaUrlHigh;
  String? thumbnailUrl;
  bool? isFollowing;
  dynamic music;
  dynamic musicStartTime;
  dynamic musicEndTime;
  String? content;

  /// Poll-specific fields (when contentType == "Poll").
  List<PollOptionItem>? options;
  int? totalVotes;
  String? status;
  String? duration;
  bool? hasVoted;
  String? votedOptionId;
  CreatedBy? createdBy;

  PostData({
    this.id,
    this.contentType,
    this.userId,
    this.shareableLink,
    this.mentionedUsers,
    this.likeCount,
    this.commentCount,
    this.shareCount,
    this.isLiked,
    this.isSaved,
    this.createdAt,
    this.updatedAt,
    this.caption,
    this.images,
    this.videos,
    this.imageAspectRatio,
    this.mediaUrl,
    this.mediaUrlLow,
    this.mediaUrlHigh,
    this.thumbnailUrl,
    this.music,
    this.musicStartTime,
    this.musicEndTime,
    this.content,
    this.options,
    this.totalVotes,
    this.status,
    this.duration,
    this.hasVoted,
    this.votedOptionId,
    this.createdBy,
    this.isFollowing,
  });

  factory PostData.fromJson(Map<String, dynamic> json) {
    final videosRaw = json["videos"];
    List<String>? videosList;
    if (videosRaw is List) {
      videosList = videosRaw.map((x) => x.toString()).toList();
    }
    final mediaUrl = json["mediaUrl"] ?? json["videoUrl"] ??
        (videosList != null && videosList.isNotEmpty ? videosList.first : null);
    final mediaUrlLow = json["mediaUrlLow"]?.toString();
    final mediaUrlHigh = json["mediaUrlHigh"]?.toString();
    // Parse aspect ratio from API: imageAspectRatio, aspectRatio, or imageWidth/imageHeight
    double? imageAspectRatio;
    if (json["imageAspectRatio"] != null) {
      imageAspectRatio = (json["imageAspectRatio"] as num).toDouble();
    } else if (json["aspectRatio"] != null) {
      imageAspectRatio = (json["aspectRatio"] as num).toDouble();
    } else if (json["imageWidth"] != null && json["imageHeight"] != null) {
      final w = (json["imageWidth"] as num).toDouble();
      final h = (json["imageHeight"] as num).toDouble();
      if (h > 0) imageAspectRatio = w / h;
    }
    // Polls use createdBy instead of userId
    UserId? author;
    if (json["userId"] != null) {
      author = UserId.fromJson(Map<String, dynamic>.from(json["userId"] as Map));
    } else if (json["createdBy"] != null) {
      author = UserId.fromJson(Map<String, dynamic>.from(json["createdBy"] as Map));
    }


    List<PollOptionItem>? pollOptions;
    if (json["options"] != null && json["options"] is List) {
      pollOptions = (json["options"] as List)
          .map((x) => PollOptionItem.fromJson(Map<String, dynamic>.from(x as Map)))
          .toList();
    }

    // Mentions can come as full objects (mentionedUsers) OR list of ids (mentionedUserIds).
    List<UserId> mentionedUsers = [];
    final mentionedRaw = json["mentionedUsers"] ?? json["mentionedUserIds"];
    if (mentionedRaw is List) {
      for (final e in mentionedRaw) {
        if (e is Map) {
          mentionedUsers.add(UserId.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    return PostData(
      id: (json["id"] ?? json["_id"])?.toString(),
      contentType: json["contentType"],
      userId: author,
      shareableLink: json["shareableLink"],
      mentionedUsers: mentionedUsers,
      likeCount: json["likeCount"],
      commentCount: json["commentCount"],
      shareCount: json["shareCount"],
      isLiked: json["isLiked"],
      isSaved: json["isSaved"],
      createdAt: json["createdAt"] == null ? null : DateTime.parse(json["createdAt"]),
      updatedAt: json["updatedAt"] == null ? null : DateTime.parse(json["updatedAt"]),
      caption: json["caption"],
      images: json["images"] == null ? [] : List<String>.from(json["images"]!.map((x) => x.toString())),
      videos: videosList,
      imageAspectRatio: imageAspectRatio,
      mediaUrl: mediaUrl,
      mediaUrlLow: mediaUrlLow,
      mediaUrlHigh: mediaUrlHigh,
      thumbnailUrl: json["thumbnailUrl"]?.toString(),
      music: json["music"],
      musicStartTime: json["musicStartTime"],
      musicEndTime: json["musicEndTime"],
      content: json["content"],
      options: pollOptions,
      totalVotes: json["totalVotes"],
      status: json["status"],
      duration: json["duration"]?.toString(),
      hasVoted: json["hasVoted"],
      votedOptionId: json["votedOptionId"]?.toString(),
      createdBy: json["createdBy"] == null ? null : CreatedBy.fromJson(json["createdBy"]),
      isFollowing: json['isFollowing'],
    );
  }

  PostData copyWith({
    List<PollOptionItem>? options,
    int? totalVotes,
    bool? hasVoted,
    String? votedOptionId,
    int? commentCount,
    bool? isFollowing,
    String? shareableLink,
    double? imageAspectRatio,
  }) {
    return PostData(
      id: id,
      contentType: contentType,
      userId: userId,
      mentionedUsers: mentionedUsers,
      likeCount: likeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      isLiked: isLiked,
      isSaved: isSaved,
      createdAt: createdAt,
      updatedAt: updatedAt,
      caption: caption,
      images: images,
      videos: videos,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      mediaUrl: mediaUrl,
      mediaUrlLow: mediaUrlLow,
      mediaUrlHigh: mediaUrlHigh,
      thumbnailUrl: thumbnailUrl,
      music: music,
      musicStartTime: musicStartTime,
      musicEndTime: musicEndTime,
      content: content,
      options: options ?? this.options,
      totalVotes: totalVotes ?? this.totalVotes,
      status: status,
      duration: duration,
      hasVoted: hasVoted ?? this.hasVoted,
      votedOptionId: votedOptionId ?? this.votedOptionId,
      createdBy: createdBy,
      isFollowing: isFollowing ?? this.isFollowing,
      shareableLink: shareableLink ?? this.shareableLink,
    );
  }

  /// True if this poll has ended (status ended/expired or duration end date in the past).
  bool get isPollExpired {
    if (status == 'ended' || status == 'expired') return true;
    if (duration != null && duration!.isNotEmpty) {
      try {
        final end = DateTime.tryParse(duration!);
        if (end != null && DateTime.now().isAfter(end)) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Voted option id for display: from [votedOptionId] or from option with [PollOptionItem.selectedByAuthUser].
  String? get displayVotedOptionId {
    if (votedOptionId != null && votedOptionId!.isNotEmpty) return votedOptionId;
    for (final o in options ?? []) {
      if (o.selectedByAuthUser == true) return o.optionId;
    }
    return null;
  }

  /// True when user has voted: from [hasVoted] or any option has [PollOptionItem.selectedByAuthUser] (no animation).
  bool get displayHasVoted =>
      hasVoted == true || (options?.any((o) => o.selectedByAuthUser == true) ?? false);

  Map<String, dynamic> toJson() => {
    "id": id,
    "contentType": contentType,
    "userId": userId?.toJson(),
    "mentionedUsers": mentionedUsers == null ? [] : List<dynamic>.from(mentionedUsers!.map((x) => x.toJson())),
    "likeCount": likeCount,
    "commentCount": commentCount,
    "shareCount": shareCount,
    "isLiked": isLiked,
    "isSaved": isSaved,
    "createdAt": createdAt?.toIso8601String(),
    "updatedAt": updatedAt?.toIso8601String(),
    "caption": caption,
    "images": images == null ? [] : List<dynamic>.from(images!.map((x) => x)),
    "videos": videos ?? [],
    "imageAspectRatio": imageAspectRatio,
    "videoUrl": mediaUrl,
    "mediaUrlLow": mediaUrlLow,
    "mediaUrlHigh": mediaUrlHigh,
    "thumbnailUrl": thumbnailUrl,
    "shareableLink": shareableLink,
    "music": music,
    "musicStartTime": musicStartTime,
    "musicEndTime": musicEndTime,
    "content": content,
    "options": options == null ? [] : options!.map((x) => x.toJson()).toList(),
    "totalVotes": totalVotes,
    "status": status,
    "duration": duration,
    "isFollowing": isFollowing,
  };
}
class CreatedBy {
  String? id;
  String? name;
  String? username;
  String? profileImage;
  bool? isAccountVerified;
  bool? isVerifiedBadge;

  CreatedBy({
    this.id,
    this.name,
    this.username,
    this.profileImage,
    this.isAccountVerified,
    this.isVerifiedBadge,
  });

  factory CreatedBy.fromJson(Map<String, dynamic> json) => CreatedBy(
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

class UserId {
  String? id;
  String? name;
  String? username;
  dynamic profileImage;
  bool? isAccountVerified;
  bool? isVerifiedBadge;

  UserId({this.id, this.name, this.username, this.profileImage, this.isAccountVerified, this.isVerifiedBadge});

  factory UserId.fromJson(Map<String, dynamic> json) => UserId(
    id: (json["id"] ?? json["_id"])?.toString(),
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

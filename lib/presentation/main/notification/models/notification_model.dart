enum NotificationType {
  comment,
  reply,
  like,
  follow,
  followRequest,
  reel,
}

class NotificationModel {
  final String id;
  final String userId;
  final String userName;
  final String userProfileImage;
  final NotificationType type;
  final String message;
  final String timestamp;
  final String? thumbnailImage;
  final String? postId;
  final int? likeCount;
  bool isRead;
  bool? isFollowRequestAccepted;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userProfileImage,
    required this.type,
    required this.message,
    required this.timestamp,
    this.thumbnailImage,
    this.postId,
    this.likeCount,
    this.isRead = false,
    this.isFollowRequestAccepted,
  });
}


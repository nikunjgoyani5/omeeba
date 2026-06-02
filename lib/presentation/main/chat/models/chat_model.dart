enum MessageType { text, byte, delivered }

enum MessageStatus { sent, delivered, read }

class ChatModel {
  final String id;
  final String userId;
  final String userName;
  final String userProfileImage;
  final String lastMessage;
  final String timestamp;
  final bool isUnread;
  final bool isVerifiedBeach;
  final int? followers;
  final MessageType? messageType;
  final MessageStatus? messageStatus;

  ChatModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userProfileImage,
    required this.lastMessage,
    required this.timestamp,
    this.isUnread = false,
    this.messageType,
    this.messageStatus,
    this.followers,
    required this.isVerifiedBeach,
  });
}

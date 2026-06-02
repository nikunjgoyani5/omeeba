class ApiEndpoints {
  // Base URL (home feed: http://143.110.244.249:4001/api/v1/home)
  // static const String baseUrl = 'http://143.110.244.249:4001/api/v1/';
  static const String quizBaseUrl = '';

  ///Auth API
  static const String login = 'auth/login';
  static const String register = 'auth/register';
  static const String verifyOtp = 'auth/verify-otp';
  static const String forgotPass = 'auth/forgot-password';
  static const String resetPass = 'auth/reset-password';
  static const String changePass = 'auth/change-password';
  static const String resendOtp = 'auth/resend-otp';

  /// Home feed (cursor-based pagination)
  static const String home = 'home';

  /// Write posts
  static const String writePosts = 'write-posts';

  /// User profile (current user)
  static const String userProfile = 'users/profile';

  /// Other user profile by userId
  static String otherUserProfile(String userId) => 'users/$userId/profile';

  /// Follow user. POST follow/{userId}
  static String followUser(String userId) => 'follow/$userId';

  /// Unfollow user. DELETE follow/{userId}
  static String unfollowUser(String userId) => 'follow/$userId';

  /// List users that the given user is following. GET follow/following?userId=&page=&limit=
  static const String followFollowing = 'follow/following';

  /// List followers of the given user. GET follow/followers?userId=&page=&limit=
  static const String followFollowers = 'follow/followers';

  /// User posts (current user). Query: page, limit.
  static const String userPosts = 'users/posts';

  /// User zeals (current user). Query: page, limit.
  static const String userZeals = 'users/zeals';

  /// User write-posts (current user). Query: page, limit.
  static const String userWritePosts = 'users/write-posts';

  /// User polls (current user). Query: page, limit.
  static const String userPolls = 'users/polls';

  /// User mentioned-posts (current user). Query: page, limit.
  static const String userMentionedPosts = 'users/mentioned-posts';

  /// Notifications. Query: page, limit.
  static const String notifications = 'notifications';

  /// Mark a single notification as read. PUT notifications/{id}/read
  static String notificationRead(String id) => 'notifications/$id/read';

  /// Mark all notifications as read. PUT notifications/read-all
  static const String notificationReadAll = 'notifications/read-all';

  /// User search (for mentions). Query: q, page, limit.
  static const String searchUsers = 'users/search';

  /// Report
  static const String reports = 'reports/categories/with-subcategories';

  /// chat module
  static String chatList(String page) => 'chat/rooms?page=$page&limit=10';

  static String chatRequestList(String page) => 'chat/requests?page=$page&limit=10';

  ///snap
  static String uploadMedia = 'media/upload';

  ///post
  static String userSearch(String page, String search) => 'users/search?search=$search&page=$page&limit=10';

  static String createPost = 'posts';

  static const String reportsSubmit = 'reports';
  static const String zealsUpload = 'zeals/upload';
  static const String zeals = 'zeals';

  /// Zeals music library (audio tracks for reels). GET zeals/music
  static const String zealsMusic = 'zeals/music';

  ///like content
  static const String likeUnlikeContent = 'content-likes/toggle';
  static const String likedUsers = 'content-likes/users';

  /// Polls
  static const String polls = 'polls';

  static String pollVote(String pollId) => 'polls/$pollId/vote';

  /// Explore (trending content). Query: contentType (explore | write | poll), page, limit.
  static const String explore = 'explore';

  /// Explore search. Query: query, type (users | posts | zeals | hashtag).
  static const String exploreSearch = 'explore/search';

  /// Explore by hashtag. Query: contentType (users | posts | zeals | hashtag).
  static String exploreHashtag(String tag) => 'explore/hashtag/$tag';

  /// Single content item by ID
  static String postById(String id) => 'posts/$id';

  static String zealById(String id) => 'zeals/$id';

  static String writePostById(String id) => 'write-posts/$id';

  static String pollById(String id) => 'polls/$id';

  /// Single content by type and ID (contentType: Post | Zeal Post | Write Post | Poll)
  static String contentByTypeAndId(String contentType, String contentId) =>
      'content/${Uri.encodeComponent(contentType)}/$contentId';

  static const String getComments = 'comments';

  static String likeUnlikeComment(String id) => 'comments/$id/like';

  static String likeUnlikeCommentReply(String id) => 'comments/replies/$id/like';

  static String commentReply(String id) => 'comments/$id/replies';

  static String deleteReply(String id) => 'comments/replies/$id';

  static String reportReplyToReply(String id) => 'comments/replies/$id/report';

  static String replyToReply(String id) => 'comments/replies/$id/replies';

  static const String notificationIdRegister = 'notifications/player-id';
  static const String toggleNotification = 'notifications/push-settings';
  static const String savePost = 'saved-content/toggle';
  static const String getSavedList = 'saved-content/list';
  static const String getEligibleUserList = 'content-shares/users';
  static  String deleteSingleMessage(String roomId , String messageId)  => 'chat/rooms/$roomId/messages/$messageId';

  /// Contact us (public / authenticated POST JSON body: name, email, subject, message)
  static const String contact = 'contact';

  /// Purchase verification
  static const String verifyApplePurchase = 'purchases/verify/apple';
  static const String verifyGooglePurchase = 'purchases/verify/google';
  static const String purchaseStatus = 'purchases/status';

}

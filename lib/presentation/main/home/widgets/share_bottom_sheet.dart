import 'dart:async';
import 'dart:ui' show ImageFilter, Rect;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:omeeba_new/core/services/socket_service.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/presentation/main/create_post/models/users_model.dart';
import 'package:omeeba_new/presentation/main/dashboard/controller/dashboard_controller.dart';

/// Share options for the "Share" section (external apps / actions).
enum ShareOption { instagram, facebook, telegram, copy, more }

class ShareBottomSheet extends StatefulWidget {
  const ShareBottomSheet({super.key, this.postId, this.postType, this.shareUrl, this.onShared});

  final String? postId;
  final String? postType;
  final String? shareUrl;
  final Function(int response)? onShared;

  static void show({String? postId, String? postType, String? shareUrl,   final Function(int response)? onShared,}) {
    Get.bottomSheet(
      ShareBottomSheet(postId: postId, postType: postType, shareUrl: shareUrl, onShared: onShared),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> with SingleTickerProviderStateMixin {
  final Set<String> _selectedRecipientIds = {};
  bool _shareInProgress = false;
  Timer? _shareTimeout;
  StreamSubscription<dynamic>? _contentSharedSub;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _contentSharedSub = SocketService.instance.onContentSharedToChatsStream.listen((data) {
      if (!mounted) return;
      if (!_shareInProgress) return;
      _shareTimeout?.cancel();
      _shareTimeout = null;
      final inner = data is Map ? data['data'] : null;
      if (inner is Map && inner['totalShareCount'] != null) {
        final n = inner['totalShareCount'];
        final count = n is int ? n : int.tryParse(n.toString()) ?? 0;
        widget.onShared?.call(count);
      }
      debugPrint("Message is send to chats");
      _pulseController.stop();
      _pulseController.reset();
      Get.back();
    });
  }

  @override
  void dispose() {
    _shareTimeout?.cancel();
    _contentSharedSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Normalize postType to backend values: "Post" | "Write Post" | "Zeal Post"
  String get _contentType {
    final t = (widget.postType ?? 'Post').toLowerCase();
    if (t.contains('zeal')) return 'Zeal Post';
    if (t.contains('poll')) return 'Poll';
    if (t.contains('write')) return 'Write Post';
    return 'Post';
  }

  void _onDone() {
    if (_shareInProgress) return;
    if (_selectedRecipientIds.isEmpty) {
      AppFunctions.showCustomToast(
        context,
        message: 'Select at least one user to share',
        isSuccess: false,
      );
      return;
    }
    setState(() => _shareInProgress = true);
    _pulseController.repeat(reverse: true);

    final contentId = widget.postId ?? '';
    final payload = {
      'contentType': _contentType,
      'contentId': contentId,
      'recipientIds': _selectedRecipientIds.toList(),
    };

    _shareTimeout?.cancel();
    _shareTimeout = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      if (!_shareInProgress) return;
      _pulseController.stop();
      _pulseController.reset();
      setState(() => _shareInProgress = false);
      AppFunctions.showCustomToast(
        context,
        message: 'Couldn\'t complete share. Try again.',
        isSuccess: false,
      );
    });

    SocketService.instance.shareToChats(
      payload,
      suppressNewMessageUntilAck: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_shareInProgress,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        child: Material(
          color: AppColors.whiteFFFFFF,
          child: SafeArea(
            top: false,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHandle(),
                    SizedBox(height: 20.h),

                    _buildSendSection(),
                    SizedBox(height: 24.h),
                    _buildShareSection(),
                    SizedBox(height: 24.h),
                  ],
                ),
                if (_shareInProgress) _buildSharingOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharingOverlay() {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: AppColors.whiteFFFFFF.withValues(alpha: 0.82),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(_pulseController.value);
                    final scale = 0.92 + 0.08 * t;
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryColor.withValues(alpha: 0.15),
                          AppColors.primaryDark.withValues(alpha: 0.22),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 36.w,
                      height: 36.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primaryColor,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 22.h),
                Text(
                  'Sharing…',
                  style: TextStyles.semiBold(18.sp, fontColor: AppColors.black2F3039),
                ),
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: Text(
                    'Sending your post to selected chats',
                    textAlign: TextAlign.center,
                    style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      height: 5.w,
      width: 55.w,
      decoration: BoxDecoration(
        color: AppColors.grayEDF1F4,
        borderRadius: BorderRadius.circular(50),
      ),
    );
  }

  Widget _buildSendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Done',
                style: TextStyles.semiBold(
                  17.sp,
                  fontColor: AppColors.transparentColor,
                ),
              ),
              Text(
                'Send',
                style: TextStyles.semiBold(
                  22.sp,
                  fontColor: AppColors.black2F3039,
                ),
              ),
              Get.find<DashboardController>().usersList.isNotEmpty ?
              _Pressable(
                onTap: _shareInProgress ? null : _onDone,
                borderRadius: BorderRadius.circular(12.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                  child: Text(
                    'Done',
                    style: TextStyles.semiBold(
                      17.sp,
                      fontColor: AppColors.primaryColor,
                    ),
                  ),
                ),
              ) : SizedBox(width: 35.w,),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 100.h,
          child: Get.isRegistered<DashboardController>()
              ? GetBuilder<DashboardController>(
                  builder: (controller) {
                    List<UserData> userList = controller.usersList;
                    if (userList.isEmpty) {
                      return Center(
                        child: Text(
                          'No users yet',
                          style: TextStyles.regular(
                            14.sp,
                            fontColor: AppColors.gray707070,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: userList.length,
                      itemBuilder: (context, index) {
                        return _buildSendUserItem(userList[index]);
                      },
                    );
                  },
                )
              : Center(
                  child: Text(
                    'No users yet',
                    style: TextStyles.regular(
                      14.sp,
                      fontColor: AppColors.gray707070,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSendUserItem(UserData user) {
    final name = user.name ?? '';
    final displayName = name.length > 12 ? '${name.substring(0, 12)}...' : name;
    final userId = user.id ?? '';
    final isSelected =
        userId.isNotEmpty && _selectedRecipientIds.contains(userId);

    return _Pressable(
      onTap: () {
        if (userId.isEmpty) return;
        setState(() {
          if (isSelected) {
            _selectedRecipientIds.remove(userId);
          } else {
            _selectedRecipientIds.add(userId);
          }
        });
      },
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: 72.w,
        margin: EdgeInsets.only(right: 16.w),
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // PROFILE IMAGE
                CommonProfileImage(imageUrl: user.profileImage?.toString(), width: 60.w, height: 60.w),

                // ORANGE BORDER (BEHIND ICON)
                if (isSelected)
                  Container(
                    width: 60.w,
                    height: 60.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryColor, width: 2.5),
                    ),
                  ),

                // CHECK ICON (ALWAYS TOP)
                if (isSelected)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white,
                      ),
                      child: Icon(Icons.check_circle, color: AppColors.primaryColor, size: 18),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 6.h),

            Text(
              displayName,
              style: TextStyles.medium(14.sp, fontColor: AppColors.black2F3039),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.center,
          child: Text(
            'Share',
            style: TextStyles.semiBold(22.sp, fontColor: AppColors.black2F3039),
          ),
        ),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildShareAction(
                label: 'Copy',
                onTap: _copyLink,
                icon: Assets.icons.icCopy.svg(height: 24),
              ),
              Gap(20),
              _buildShareAction(
                label: 'More app',
                onTap: _openMoreApps,
                icon: Icon(Icons.more_horiz),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShareAction({
    required String label,
    required VoidCallback onTap,
    required Widget icon,
  }) {
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: AppColors.grayEDF1F4,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyles.medium(
                12.sp,
                fontColor: AppColors.black2F3039,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Public web base for post links (must match Universal Links / site).
  String _shareUrlText() {
    return widget.shareUrl ?? 'https://omeeba.co.in/post/${widget.postId ?? ''}';
  }

  /// Popover anchor for iOS share sheet (required on iPad). Unused on Android.
  Rect _shareSheetAnchor() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final sz = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(sz.width / 2, sz.height / 2),
      width: 2,
      height: 2,
    );
  }

  Future<void> _copyLink() async {
    final url = _shareUrlText();
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    AppFunctions.showCustomToast(context, message: 'Link copied', isSuccess: true);
    Get.back();
  }

  Future<void> _openMoreApps() async {
    final url = _shareUrlText();
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final Rect? shareOrigin = isIOS ? _shareSheetAnchor() : null;
    Get.back();
    if (isIOS) {
      // Let the bottom sheet finish closing before presenting UIActivityViewController.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await Share.share(url, sharePositionOrigin: shareOrigin);
    } else {
      await Share.share(url);
    }
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: widget.borderRadius,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onHighlightChanged: (value) {
          if (_pressed == value) return;
          setState(() => _pressed = value);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _pressed ? 0.82 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

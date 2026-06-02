import 'dart:math' as math;
import 'package:omeeba_new/core/models/follow_list_response_model.dart';
import 'package:omeeba_new/core/utils/exports.dart';
import 'package:omeeba_new/core/widgets/common_app_bar.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/presentation/main/other_user_profile/controller/other_user_profile_controller.dart';
import 'package:omeeba_new/presentation/main/myprofile/widgets/following_list_unfollow_sheet.dart';

class FollowingListView extends StatefulWidget {
  const FollowingListView({super.key});

  /// Expected [Get.arguments]: { 'userId': String, 'listType': 'following'|'followers', 'username': String? }
  static Map<String, dynamic>? get routeArguments {
    try {
      final args = Get.arguments;
      if (args is Map<String, dynamic>) return args;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  State<FollowingListView> createState() => _FollowingListViewState();
}

class _FollowingListViewState extends State<FollowingListView> {
  late OtherUserProfileController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final args = FollowingListView.routeArguments ?? {};
    final listType = args['listType']?.toString() ?? 'following';
    if (!Get.isRegistered<OtherUserProfileController>()) {
      Get.put(OtherUserProfileController());
    }
    _controller = Get.find<OtherUserProfileController>();
    _controller.setFollowListType(listType);
    _controller.loadFollowList();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) _controller.loadMoreFollowList();
  }

  String get _title => _controller.isFollowListFollowing ? 'Following' : 'Audience';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CommonAppBar(title: _title),
      body: Obx(() {
        if (_controller.followListLoading.value && _controller.followListItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                SizedBox(height: 16.h),
                Text('Loading...', style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070)),
              ],
            ),
          );
        }
        if (_controller.followListItems.isEmpty) {
          return Center(
            child: Text(
              _controller.isFollowListFollowing ? 'No following yet' : 'No followers yet',
              style: TextStyles.regular(14.sp, fontColor: AppColors.gray707070),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => _controller.loadFollowList(),
          color: AppColors.primaryColor,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            padding: EdgeInsets.only(top: 8.h, bottom: 24.h),
            itemCount: _controller.followListItems.length + (_controller.followListLoadMoreLoading.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _controller.followListItems.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Center(
                    child: SizedBox(width: 24.w, height: 24.h, child: const CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              }
              final item = _controller.followListItems[index];
              return _FollowListItemWidget(
                item: item,
                controller: _controller,
                onTap: () {
                  final id = item.id;
                  if (id != null && id.isNotEmpty) {
                    Get.toNamed(AppRoutes.otherUserProfile, arguments: id);
                  }
                },
              );
            },
          ),
        );
      }),
    );
  }
}

class _FollowListItemWidget extends StatelessWidget {
  const _FollowListItemWidget({required this.item, required this.controller, required this.onTap});

  final FollowListItem item;
  final OtherUserProfileController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelf = item.isSelf;
    final isFollowing = item.isFollowing;
    final loading = controller.isFollowListActionLoading(item.id);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Stack(
              children: [
                CommonProfileImage(imageUrl: item.profileImage, width: 48.w, height: 48.w),

                if (item.isVerifiedBadge == true)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Assets.icons.icVerifyBadge.svg(width: 17.w, height: 17.w),
                  ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name ?? item.username ?? 'User',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.medium(17.sp, fontColor: AppColors.black2F3039),
                        ),
                      ),
                      Gap(5.h),
                      if (item.isVerifiedBadge == true) ...[
                        Assets.icons.icVerifyBadgeSmallSize.svg(width: 16.w, height: 16.h),
                      ],
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '@${item.username ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.medium(14.sp, fontColor: AppColors.gray707070),
                  ),
                  // if (item.bio != null && item.bio!.isNotEmpty) ...[
                  //   SizedBox(height: 4.h),
                  //   Text(
                  //     item.bio!,
                  //     style: TextStyles.regular(12.sp, fontColor: AppColors.gray8C9499),
                  //     maxLines: 2,
                  //     overflow: TextOverflow.ellipsis,
                  //   ),
                  // ],
                ],
              ),
            ),
            SizedBox(width: 12.w),
            if (isSelf)
              SizedBox.shrink()
            else
              GestureDetector(
                onTap: loading
                    ? null
                    : () {
                        final id = item.id;
                        if (id == null || id.isEmpty) return;
                        if (isFollowing) {
                          FollowingListUnfollowSheet.show(controller: controller, targetUserId: id);
                        } else {
                          controller.followUserInList(
                            id,
                            onError: (msg) => AppFunctions().showToast(msg, bgColor: AppColors.red),
                          );
                        }
                      },
                child: Container(
                  height: 32.h,
                  width: 100.w,
                  decoration: BoxDecoration(
                    gradient: isFollowing
                        ? null
                        : LinearGradient(
                            colors: const [AppColors.primaryColor, AppColors.primaryDark],
                            stops: const [-0.0864, 0.798],
                            transform: GradientRotation((320.33 - 90) * math.pi / 180),
                          ),
                    color: isFollowing ? AppColors.grayEDF1F4 : null,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Center(
                    child: loading
                        ? SizedBox(
                            width: 18.w,
                            height: 18.h,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.whiteFFFFFF),
                          )
                        : Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: TextStyles.medium(
                              14.sp,
                              fontColor: isFollowing ? AppColors.black2F3039 : AppColors.whiteFFFFFF,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

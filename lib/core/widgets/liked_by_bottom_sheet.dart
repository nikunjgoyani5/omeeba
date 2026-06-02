// import 'package:omeeba_new/core/models/follow_list_response_model.dart';
// import 'package:omeeba_new/core/widgets/common_profile_image.dart';
//
// import '../utils/exports.dart';
//
// class LikedByBottomSheet extends StatefulWidget {
//   const LikedByBottomSheet({
//     super.key,
//     required this.contentId,
//     required this.contentType,
//   });
//
//   final String contentId;
//   final String contentType;
//
//   static Future<void> show({
//     required BuildContext context,
//     required String contentId,
//     required String contentType,
//   }) async {
//     if (contentId.trim().isEmpty || contentType.trim().isEmpty) return;
//     await showModalBottomSheet<void>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: AppColors.whiteFFFFFF,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
//       ),
//       builder: (_) => FractionallySizedBox(
//         heightFactor: 0.75,
//         child: LikedByBottomSheet(contentId: contentId, contentType: contentType),
//       ),
//     );
//   }
//
//   @override
//   State<LikedByBottomSheet> createState() => _LikedByBottomSheetState();
// }
//
// class _LikedByBottomSheetState extends State<LikedByBottomSheet> {
//   final TextEditingController _searchController = TextEditingController();
//
//   final List<FollowListItem> _staticUsers = <FollowListItem>[
//     FollowListItem(id: '1', name: 'Jakob Curtis', username: 'jakobcurtis', profileImage: '', status: 'not_following'),
//     FollowListItem(id: '2', name: 'Jordyn Siphron', username: 'jordyn', profileImage: '', status: 'following'),
//     FollowListItem(id: '3', name: 'Chance Carder', username: 'chancecarder', profileImage: '', status: 'not_following'),
//     FollowListItem(id: '4', name: 'Arlene McCoy', username: 'arlenemccoy', profileImage: '', status: 'not_following'),
//     FollowListItem(id: '5', name: 'Cody Fisher', username: 'codyfisher', profileImage: '', status: 'following'),
//     FollowListItem(id: '6', name: 'Savannah Nguyen', username: 'savannah', profileImage: '', status: 'not_following'),
//   ];
//   List<FollowListItem> _filteredUsers = <FollowListItem>[];
//
//   @override
//   void initState() {
//     super.initState();
//     _filteredUsers = List<FollowListItem>.from(_staticUsers);
//   }
//
//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   void _onSearchChanged(String value) {
//     final query = value.trim().toLowerCase();
//     setState(() {
//       if (query.isEmpty) {
//         _filteredUsers = List<FollowListItem>.from(_staticUsers);
//       } else {
//         _filteredUsers = _staticUsers.where((user) {
//           final name = (user.name ?? '').toLowerCase();
//           final username = (user.username ?? '').toLowerCase();
//           return name.contains(query) || username.contains(query);
//         }).toList();
//       }
//     });
//   }mode
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       top: false,
//       child: Padding(
//         padding: EdgeInsets.only(
//           left: 16.w,
//           right: 16.w,
//           top: 8.h,
//           bottom: MediaQuery.of(context).viewInsets.bottom + 12.h,
//         ),
//         child: Column(
//           children: [
//             Container(
//               width: 42.w,
//               height: 4.h,
//               decoration: BoxDecoration(
//                 color: AppColors.grayEDF1F4,
//                 borderRadius: BorderRadius.circular(99.r),
//               ),
//             ),
//             Gap(14.h),
//             Text('Liked By', style: TextStyles.bold(24.sp, fontColor: AppColors.black2F3039)),
//             Gap(14.h),
//             Container(
//               height: 46.h,
//               decoration: BoxDecoration(
//                 color: AppColors.grayEDF1F4,
//                 borderRadius: BorderRadius.circular(24.r),
//               ),
//
//               child: TextField(
//                 controller: _searchController,
//                 onChanged: _onSearchChanged,
//                 decoration: InputDecoration(
//                   hintText: 'Search people',
//                   hintStyle: TextStyles.medium(
//                     17.sp,
//                     fontColor: AppColors.g707070ray,fontWeight: FontWeight.w500,
//                   ),
//
//                   prefixIcon: Padding(
//                     padding: EdgeInsets.only(left: 12.w, right: 8.w),
//                     child: Assets.icons.icGreysearch.svg(
//                       width: 26.w,
//                       height: 26.h,
//                     ),
//                   ),
//
//                   prefixIconConstraints: BoxConstraints(
//                     minWidth: 30.w,
//                     minHeight: 30.h,
//                   ),
//
//                   border: InputBorder.none,
//                   contentPadding: EdgeInsets.symmetric(vertical: 12.h),
//                 ),
//               ),
//             ),
//             Gap(12.h),
//             Expanded(
//               child: _filteredUsers.isEmpty
//                   ? Center(
//                       child: Text(
//                         _searchController.text.trim().isEmpty ? 'No likes yet' : 'No users found',
//                         style: TextStyles.regular(14.sp, fontColor: AppColors.g707070ray),
//                       ),
//                     )
//                   : ListView.separated(
//                       itemCount: _filteredUsers.length,
//                       separatorBuilder: (_, __) => SizedBox(height: 2.h),
//                       itemBuilder: (context, index) => _UserTile(
//                         user: _filteredUsers[index],
//                       ),
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class _UserTile extends StatelessWidget {
//   const _UserTile({
//     required this.user,
//   });
//
//   final FollowListItem user;
//
//   @override
//   Widget build(BuildContext context) {
//     final isFollowing = user.isFollowing;
//
//     return InkWell(
//       onTap: () {
//         final id = user.id;
//         if (id != null && id.isNotEmpty) {
//           Get.toNamed(AppRoutes.otherUserProfile, arguments: {'userId': id}, preventDuplicates: false);
//         }
//       },
//       child: Padding(
//         padding: EdgeInsets.symmetric(vertical: 8.h),
//         child: Row(
//           children: [
//             CommonProfileImage(imageUrl: user.profileImage, width: 44.w, height: 44.w),
//             SizedBox(width: 10.w),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     user.name ?? user.username ?? 'User',
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyles.medium(18.sp, fontColor: AppColors.black2F3039),
//                   ),
//                   Text(
//                     '@${user.username ?? ''}',
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyles.regular(14.sp, fontColor: AppColors.g707070ray),
//                   ),
//                 ],
//               ),
//             ),
//             GestureDetector(
//               onTap: () {},
//               child: Container(
//                 height: 34.h,
//                 constraints: BoxConstraints(minWidth: 92.w),
//                 padding: EdgeInsets.symmetric(horizontal: 14.w),
//                 decoration: BoxDecoration(
//                   gradient: isFollowing
//                       ? null
//                       : const LinearGradient(
//                           colors: [AppColors.primaryColor, AppColors.primaryDark],
//                         ),
//                   color: isFollowing ? AppColors.grayEDF1F4 : null,
//                   borderRadius: BorderRadius.circular(8.r),
//                 ),
//                 child: Center(
//                   child: Text(
//                     isFollowing ? 'Message' : 'Follow',
//                     style: TextStyles.medium(
//                       13.sp,
//                       fontColor: isFollowing ? AppColors.black2F3039 : AppColors.whiteFFFFFF,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }



import 'package:omeeba_new/core/models/userlikelist_model.dart';
import 'package:omeeba_new/core/widgets/common_loader.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/presentation/main/chat/models/chat_model.dart';
import 'package:shimmer/shimmer.dart';

import '../../presentation/main/post/controller/liked_users_controller.dart';
import '../utils/exports.dart';

class LikedByBottomSheet extends StatefulWidget {
  const LikedByBottomSheet({
    super.key,
    required this.contentId,
    required this.contentType,
  });

  final String contentId;
  final String contentType;

  static Future<void> show({
    required BuildContext context,
    required String contentId,
    required String contentType,
  }) async {
    if (contentId.trim().isEmpty || contentType.trim().isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.whiteFFFFFF,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20.r),
        ),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: LikedByBottomSheet(
          contentId: contentId,
          contentType: contentType,
        ),
      ),
    );
  }

  @override
  State<LikedByBottomSheet> createState() => _LikedByBottomSheetState();
}

class _LikedByBottomSheetState extends State<LikedByBottomSheet> {
  late final LikedUsersController controller;

  @override
  void initState() {
    super.initState();

    controller = Get.put(LikedUsersController());

    controller.getLikedUsers(
      contentType: widget.contentType,
      contentId: widget.contentId,
    );
  }

  @override
  void dispose() {
    controller.searchController.dispose();
    Get.delete<LikedUsersController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 8.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12.h,
        ),
        child: Column(
          children: [
            Container(
              width: 42.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.grayEDF1F4,
                borderRadius: BorderRadius.circular(99.r),
              ),
            ),

            Gap(14.h),

            Text(
              'Liked By',
              style: TextStyles.bold(
                24.sp,
                fontColor: AppColors.black2F3039,
              ),
            ),

            Gap(14.h),

            Container(
              height: 46.h,
              decoration: BoxDecoration(
                color: AppColors.grayEDF1F4,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: TextField(
                controller: controller.searchController,
                onChanged: controller.searchUser,
                decoration: InputDecoration(
                  hintText: 'Search people',
                  hintStyle: TextStyles.medium(
                    17.sp,
                    fontColor: AppColors.g707070ray,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(
                      left: 12.w,
                      right: 8.w,
                    ),
                    child: Assets.icons.icGreysearch.svg(
                      width: 26.w,
                      height: 26.h,
                    ),
                  ),
                  prefixIconConstraints: BoxConstraints(
                    minWidth: 30.w,
                    minHeight: 30.h,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 12.h,
                  ),
                ),
              ),
            ),

            Gap(12.h),

            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const _LikedByListShimmer();
                }

                if (controller.filteredUsers.isEmpty) {
                  return Center(
                    child: Text(
                      controller.searchController.text.trim().isEmpty
                          ? 'No likes yet'
                          : 'No users found',
                      style: TextStyles.regular(
                        14.sp,
                        fontColor: AppColors.g707070ray,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: controller.filteredUsers.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: 2.h),
                  itemBuilder: (context, index) {
                    final user = controller.filteredUsers[index];

                    return _UserTile(
                      user: user,
                      controller: controller,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.controller,
  });

  final LikedUser user;
  final LikedUsersController controller;

  @override
  Widget build(BuildContext context) {
    final isFollowing = user.isFollowing;

    return InkWell(
      onTap: () async {
        final id = user.id;

        if (id != null && id.isNotEmpty) {
          await Get.toNamed(
            AppRoutes.otherUserProfile,
            arguments: {'userId': id},
            preventDuplicates: false,
          );
          await controller.syncLikedUserFollowStatus(id);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 8.h,
        ),
        child: Row(
          children: [
            CommonProfileImage(
              imageUrl: user.profileImage,
              width: 44.w,
              height: 44.w,
            ),

            SizedBox(width: 10.w),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name ??
                        user.username ??
                        'User',
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyles.medium(
                      18.sp,
                      fontColor:
                      AppColors.black2F3039,
                    ),
                  ),

                  Text(
                    '@${user.username ?? ''}',
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyles.regular(
                      14.sp,
                      fontColor:
                      AppColors.g707070ray,
                    ),
                  ),
                ],
              ),
            ),

            if (!user.isSelf)
              Obx(() {
                final loading =
                    controller.followActionLoadingForUserId.value == user.id;
                final latestUser = controller.filteredUsers.firstWhereOrNull(
                  (u) => u.id == user.id,
                );
                final latestIsFollowing = latestUser?.isFollowing ?? isFollowing;
                return GestureDetector(
                  onTap: loading
                      ? null
                      : () {
                          if (latestIsFollowing) {
                            final chatModel = ChatModel(
                              id: '',
                              userId: user.id,
                              userName: user.name.isNotEmpty
                                  ? user.name
                                  : (user.username.isNotEmpty
                                      ? user.username
                                      : 'Unknown'),
                              userProfileImage: user.profileImage,
                              lastMessage: '',
                              timestamp: '',
                              followers: null,
                              isVerifiedBeach: false,
                            );
                            Get.toNamed(
                              AppRoutes.chatDetails,
                              arguments: {
                                'chat': chatModel,
                                'isRequest': false,
                              },
                            );
                          } else {
                            controller.followLikedUser(
                              user.id,
                              onError: (msg) {
                                AppFunctions().showToast(
                                  msg,
                                  bgColor: AppColors.red,
                                );
                              },
                            );
                          }
                        },
                  child: Container(
                    height: 34.h,
                    constraints: BoxConstraints(
                      minWidth: 92.w,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                    ),
                    decoration: BoxDecoration(
                      gradient: latestIsFollowing
                          ? null
                          : const LinearGradient(
                              colors: [
                                AppColors.primaryColor,
                                AppColors.primaryDark,
                              ],
                            ),
                      color: latestIsFollowing ? AppColors.grayEDF1F4 : null,
                      borderRadius: BorderRadius.circular(
                        8.r,
                      ),
                    ),
                    child: Center(
                      child: loading
                          ? CommonLoader(
                              size: 18,
                              color: latestIsFollowing
                                  ? AppColors.black2F3039
                                  : AppColors.whiteFFFFFF,
                            )
                          : Text(
                              latestIsFollowing ? 'Message' : 'Follow',
                              style: TextStyles.medium(
                                13.sp,
                                fontColor: latestIsFollowing
                                    ? AppColors.black2F3039
                                    : AppColors.whiteFFFFFF,
                              ),
                            ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder while liked-by users are loading (e.g. opening the sheet).
class _LikedByListShimmer extends StatelessWidget {
  const _LikedByListShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grayEDF1F4,
      highlightColor: AppColors.greyF3F4F5,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 10,
        separatorBuilder: (_, __) => SizedBox(height: 2.h),
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  color: AppColors.whiteFFFFFF,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16.h,
                      width: 140.w,
                      decoration: BoxDecoration(
                        color: AppColors.whiteFFFFFF,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      height: 14.h,
                      width: 100.w,
                      decoration: BoxDecoration(
                        color: AppColors.whiteFFFFFF,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 34.h,
                width: 92.w,
                decoration: BoxDecoration(
                  color: AppColors.whiteFFFFFF,
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:omeeba_new/core/models/post_list_response_model.dart';
import 'package:omeeba_new/core/routes/app_routes.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';
import 'package:omeeba_new/core/widgets/common_network_image.dart';
import 'package:omeeba_new/core/widgets/common_profile_image.dart';
import 'package:omeeba_new/core/widgets/liked_by_bottom_sheet.dart';
import 'package:omeeba_new/core/widgets/press_scale_button.dart';
import 'package:omeeba_new/gen/assets.gen.dart';
import 'package:readmore/readmore.dart';

/// Renders a single [PostData] in the home feed with cached network images.
class HomeFeedPostItem extends StatelessWidget {
  const HomeFeedPostItem({super.key, required this.post, this.heroTagPrefix});

  final PostData post;
  final String? heroTagPrefix;

  static String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final d = now.difference(date);
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'now';
  }

  String get _caption => post.caption ?? post.content ?? '';

  List<String> get _imageUrls {
    final list = post.images;
    if (list != null && list.isNotEmpty) return list;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = _imageUrls;
    final hasMultiple = imageUrls.length > 1;
    final profileImageUrl = post.userId?.profileImage is String ? post.userId!.profileImage as String : null;

    return Container(
      color: AppColors.whiteFFFFFF,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Get.toNamed(AppRoutes.otherUserProfile, arguments: post.userId?.id),
                  child: Row(
                    children: [
                      CommonProfileImage(
                        imageUrl: profileImageUrl,
                        width: 40.r,
                        height: 40.r,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        post.userId?.name ?? post.userId?.username ?? 'User',
                        style: TextStyles.medium(16.sp, fontColor: AppColors.gray707070),
                      ),
                      Gap(5.w),
                      Container(
                        height: 6.h,
                        width: 6.w,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.whiteEAEAEA),
                      ),
                      Gap(5.w),
                      Text(_timeAgo(post.createdAt), style: TextStyles.medium(16.sp, fontColor: AppColors.gray707070)),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  // onTap: () => ReportBottomSheet.show(),
                  child: Icon(Icons.more_horiz, color: AppColors.black2F3039, size: 20.sp),
                ),
              ],
            ),
          ),
          if (_caption.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.postDetails),
                child: ReadMoreText(
                  _caption,
                  trimMode: TrimMode.Line,
                  trimLines: 2,
                  colorClickableText: Colors.pink,
                  trimCollapsedText: 'More',
                  trimExpandedText: 'Less',
                  style: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
                  moreStyle: TextStyles.medium(
                    14.sp,
                    fontColor: AppColors.black000000,
                    textDecoration: TextDecoration.underline,
                    decorationsColor: AppColors.black000000,
                  ),
                  lessStyle: TextStyles.medium(
                    14.sp,
                    fontColor: AppColors.black000000,
                    textDecoration: TextDecoration.underline,
                    decorationsColor: AppColors.black000000,
                  ),
                ),
              ),
            ),
          SizedBox(height: 12.h),
          _buildImageSection(context, imageUrls, hasMultiple),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Row(
                  children: [
                    post.isLiked == true ? Assets.icons.icLike.svg() : Assets.icons.icLikeBorder.svg(),
                    SizedBox(width: 4.w),
                    PressScaleButton(
                      onTap: () {
                        LikedByBottomSheet.show(
                          context: context,
                          contentId: post.id ?? '',
                          contentType: post.contentType ?? 'Post',
                        );
                      },
                      child: Text(
                        _formatCount(post.likeCount ?? 0),
                        style: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 20.w),
                Row(
                  children: [
                    Assets.icons.icComment.svg(),
                    SizedBox(width: 4.w),
                    Text(
                      _formatCount(post.commentCount ?? 0),
                      style: TextStyles.regular(16.sp, fontColor: AppColors.black2F3039),
                    ),
                  ],
                ),
                SizedBox(width: 20.w),
                Assets.icons.icShare.svg(),
                const Spacer(),
                Assets.icons.icSave.svg(),
              ],
            ),
          ),
          Gap(8.h),
          Container(height: 12.h, width: double.infinity, color: AppColors.grayEDF1F4),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, List<String> imageUrls, bool hasMultiple) {
    final size = MediaQuery.of(context).size.width;
    if (imageUrls.isEmpty) {
      return Container(
        width: double.infinity,
        height: size,
        color: AppColors.grayEDF1F4,
        child: Assets.icons.icImgPlaceholder.image(fit: BoxFit.contain),
      );
    }

    if (hasMultiple) {
      return SizedBox(
        height: size,
        width: double.infinity,
        child: PageView.builder(
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            return CommonNetworkImage(
              imageUrl: imageUrls[index],
              width: double.infinity,
              height: size,
              fit: BoxFit.cover,
            );
          },
        ),
      );
    }

    return CommonNetworkImage(imageUrl: imageUrls.first, width: double.infinity, height: size, fit: BoxFit.cover);
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}k';
    }
    return count.toString();
  }
}

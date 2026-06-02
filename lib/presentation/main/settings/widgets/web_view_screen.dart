import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:omeeba_new/core/utils/exports.dart';

import '../../../../core/widgets/common_app_bar.dart';
import '../controller/web_view_controller.dart';


class CommonWebViewScreen extends StatelessWidget {
  final String url;
  final String name;

  const CommonWebViewScreen({
    super.key,
    required this.url,
    required this.name,
  });

  static void open({required String url, required String name}) {
    Get.to(
          () => CommonWebViewScreen(url: url, name: name),
      transition: Transition.rightToLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CommonWebViewController>(
      init: CommonWebViewController(initialUrl: url, title: name),
      builder: (controller) {
        final uri = controller.webUri;

        return Scaffold(
          backgroundColor: AppColors.whiteFFFFFF,
          appBar: CommonAppBar(title: name, showBackButton: true),
          body: uri == null
              ? _buildErrorView(
            message: 'Invalid URL format.',
            onRetry: () => Get.back(),
          )
              : Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: uri),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  useHybridComposition: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  cacheEnabled: true,
                  allowsInlineMediaPlayback: true,
                  mediaPlaybackRequiresUserGesture: false,
                ),
                onWebViewCreated: controller.onWebViewCreated,
                onLoadStart: (_, url) =>
                    controller.onLoadStart(url),
                onLoadStop: (_, url) =>
                    controller.onLoadStop(url),
                onProgressChanged: (_, p) =>
                    controller.onProgressChanged(p),
                onReceivedError: (_, req, err) =>
                    controller.onReceivedError(req, err),
                onReceivedHttpError: (_, req, res) =>
                    controller.onReceivedHttpError(req, res),
              ),

              if (controller.isLoading && !controller.hasError)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: controller.progress,
                    backgroundColor: AppColors.grayEDF1F4,
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.primaryColor,
                    ),
                    minHeight: 3.h,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorView({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                color: AppColors.redFF5353, size: 72.sp),
            SizedBox(height: 20.h),
            Text(
              'Failed to load page',
              style: TextStyles.semiBold(
                20.sp,
                fontColor: AppColors.black2F3039,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              message,
              style: TextStyles.regular(
                15.sp,
                fontColor: AppColors.gray8C9499,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(
                'Retry',
                style: TextStyles.medium(
                  16.sp,
                  fontColor: AppColors.whiteFFFFFF,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


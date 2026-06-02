import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class CommonWebViewController extends GetxController {
  final String initialUrl;
  final String title;

  CommonWebViewController({
    required this.initialUrl,
    required this.title,
  });

  InAppWebViewController? webViewController;

  bool isLoading = true;
  bool hasError = false;
  double progress = 0.0;
  String errorMessage = '';

  /// Normalize URL
  String get normalizedUrl {
    var url = initialUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  WebUri? get webUri {
    try {
      return WebUri(normalizedUrl);
    } catch (_) {
      return null;
    }
  }

  void onWebViewCreated(InAppWebViewController controller) {
    webViewController = controller;
  }

  void onLoadStart(WebUri? url) {
    isLoading = true;
    hasError = false;
    progress = 0.0;
    update();
  }

  void onLoadStop(WebUri? url) {
    isLoading = false;
    progress = 1.0;
    update();
  }

  void onProgressChanged(int p) {
    progress = p / 100.0;
    update();
  }

  void onReceivedError(
      WebResourceRequest request,
      WebResourceError error,
      ) {
    isLoading = false;
    hasError = true;
    errorMessage = error.description.isNotEmpty
        ? error.description
        : 'Failed to load page. Please check your internet connection.';
    update();
  }

  void onReceivedHttpError(
      WebResourceRequest request,
      WebResourceResponse response,
      ) {
    isLoading = false;
    hasError = true;
    errorMessage =
    'HTTP Error ${response.statusCode}: Failed to load page';
    update();
  }

  Future<void> reload() async {
    if (webViewController == null) return;

    hasError = false;
    errorMessage = '';
    isLoading = true;
    update();

    await webViewController!.reload();
  }

  @override
  void onClose() {
    webViewController = null;
    super.onClose();
  }
}
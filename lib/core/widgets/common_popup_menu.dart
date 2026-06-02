import '../../presentation/main/home/controller/home_controller.dart';
import '../exceptions/app_exception.dart';
import '../models/post_list_response_model.dart';
import '../repository/notification_repository.dart';
import '../utils/exports.dart';
import 'common_post_detail_widget.dart';
import 'delete_confirmation_dialog.dart';

class CommonPopupMenu {
  static OverlayEntry? _currentEntry;
  static NavigatorState? _navigator;

  static void show({
    required BuildContext context,
    required GlobalKey anchorKey,
    required VoidCallback onSave,
    required VoidCallback onReport,
    required VoidCallback onCopyLink,
    required VoidCallback onShare,
    required VoidCallback onDelete,
    bool showDelete = false,
    required bool isSave,
    String? deleteContentId,
    String? deleteContentType,
    PostData? post,
  }) {
    hide(); // close any open menu

    final anchorContext = anchorKey.currentContext;
    if (anchorContext == null) return;

    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final animationController = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 160), // ⚡ faster
    );

    final scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animationController, curve: Curves.easeOut));

    final opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: animationController, curve: Curves.easeOut));

    void onDeleteTapped() {
      hide();
      showDeleteConfirmationDialog(context).then((confirmed) {
        if (!confirmed) return;
        final contentId = deleteContentId;
        final contentType = deleteContentType ?? 'Post';
        if (contentId != null && contentId.isNotEmpty) {
          final repo = Get.isRegistered<NotificationRepository>()
              ? Get.find<NotificationRepository>()
              : Get.put(NotificationRepository());
          repo.deleteContentByTypeAndId(
            contentId: contentId,
            contentType: contentType,
            onSuccess: (response) {
              AppFunctions().showToast(response.message ?? "Content deleted successfully", bgColor: AppColors.green);
              if (Get.isRegistered<HomeController>()) {
                Get.find<HomeController>().feedData.value!.posts!.removeWhere((element) => element.id == contentId);
                Get.find<HomeController>().feedData.refresh();
              }
              onDelete();
            },
            onError: (AppException e) {
              AppFunctions().showToast(e.message, bgColor: AppColors.red);
            },
          );
        } else {
          onDelete();
        }
      });
    }

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => PopupMenuOverlay(
        post: post,
        position: position,
        size: size,
        isSave: isSave,
        scaleAnimation: scaleAnimation,
        opacityAnimation: opacityAnimation,
        showDelete: showDelete,
        onDismiss: () {
          animationController.reverse().then((_) {
            entry.remove();
            animationController.dispose();
            _currentEntry = null;
            _navigator?.pop();
            _navigator = null;
          });
        },
        onSave: () {
          hide();
          onSave();
        },
        onReport: () {
          hide();
          onReport();
        },
        onCopyLink: () {
          hide();
          onCopyLink();
        },
        onShare: () {
          hide();
          onShare();
        },
        onDelete: onDeleteTapped,
      ),
    );

    _currentEntry = entry;
    _navigator = Navigator.of(context);
    Overlay.of(context, rootOverlay: true).insert(entry);
    animationController.forward(); // 🚀 instant

    // Push a transparent route so system back closes the popup instead of the screen
    _navigator!.push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) hide();
          },
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
    _navigator?.pop();
    _navigator = null;
  }
}

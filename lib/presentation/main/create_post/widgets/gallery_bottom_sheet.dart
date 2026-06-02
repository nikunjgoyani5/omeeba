import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:omeeba_new/core/utils/exports.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:omeeba_new/presentation/main/create_post/controller/create_post_controller.dart';
import 'package:omeeba_new/presentation/main/create_post/widgets/video_preview_bottom_sheet.dart';
import 'package:omeeba_new/presentation/main/post/views/post_data_screen.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryBottomSheet extends StatefulWidget {
  final bool videoOnly;

  const GalleryBottomSheet({super.key, this.videoOnly = false});

  static void show({bool videoOnly = false}) {
    Get.bottomSheet(
      GalleryBottomSheet(videoOnly: videoOnly),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  State<GalleryBottomSheet> createState() => _GalleryBottomSheetState();
}

class _GalleryBottomSheetState extends State<GalleryBottomSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  OverlayEntry? _overlayEntry;
  late AnimationController _menuAnimationController;
  late Animation<double> _menuScaleAnimation;
  late Animation<double> _menuOpacityAnimation;
  final GlobalKey _dropdownKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _menuAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _menuScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _menuAnimationController, curve: Curves.easeOutCubic));
    _menuOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _menuAnimationController, curve: Curves.easeOutCubic));

    // On open: clear any previous selection so nothing is selected by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Get.find<CreatePostController>();
      controller.clearSelectedAssets();
      controller.loadAlbumsForGallery(widget.videoOnly);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeMenu();
    _menuAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Get.find<CreatePostController>().recheckGalleryPermissionAndLoad();
    }
  }

  void _showMenu() {
    if (_overlayEntry != null) return;

    final RenderBox? renderBox = _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset position = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    final CreatePostController controller = Get.find<CreatePostController>();
    final List<AssetPathEntity> albums = controller.albums.toList();

    _overlayEntry = OverlayEntry(
      builder: (context) => _PopupMenuOverlay(
        position: position,
        size: size,
        scaleAnimation: _menuScaleAnimation,
        opacityAnimation: _menuOpacityAnimation,
        albums: albums,
        onAlbum: (album) {
          _closeMenu();
          controller.selectAlbum(album.id, album.name);
        },
        onAll: () {
          _closeMenu();
          controller.changeAlbumType('All');
        },
        onDismiss: _closeMenu,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _menuAnimationController.forward();
  }

  void _closeMenu() {
    _menuAnimationController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final CreatePostController controller = Get.find<CreatePostController>();

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        log('close menu:::::::');
        _closeMenu();
      },
      child: Container(
        height: Get.height * 0.9,
        decoration: BoxDecoration(
          color: AppColors.whiteFFFFFF,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12.h),
              height: 5.w,
              width: 55.w,
              decoration: BoxDecoration(color: AppColors.grayEDF1F4, borderRadius: BorderRadius.circular(50)),
            ),
            Gap(16.h),
            _buildHeader(controller, context, widget.videoOnly),
            Expanded(child: _buildImageGrid(controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CreatePostController controller, BuildContext context, bool videoOnly) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => Get.back(),
            child: Container(
              alignment: Alignment.center,
              color: AppColors.transparentColor,
              height: 40,
              width: 40,

              child: Assets.icons.icArrowBack.image(scale: 3.5),
            ),
          ),

          Obx(() {
            return Expanded(
              child: GestureDetector(
                key: _dropdownKey,
                onTap: () => _showMenu(),
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        controller.selectedAlbumType.value,
                        style: TextStyles.semiBold(20.sp, fontColor: AppColors.black2F3039),
                      ),
                      Gap(4.w),
                      Icon(Icons.keyboard_arrow_down, size: 20.sp, color: AppColors.black2F3039),
                    ],
                  ),
                ),
              ),
            );
          }),

          Obx(
            () => Container(
              margin: EdgeInsets.only(right: 16.w),
              width: 60,
              child: GestureDetector(
                onTap: controller.selectedAssets.isEmpty
                    ? null
                    : () async {
                        // Check if selected assets contain videos
                        final selectedAssets = controller.selectedAssets;
                        final videos = selectedAssets.where((asset) => asset.type == AssetType.video).toList();

                        // If only one video is selected, show video preview
                        if (videos.isNotEmpty) {
                          Get.back(); // Close gallery bottom sheet
                          VideoPreviewBottomSheet.show(videoAsset: videos.first);
                        } else {
                          // Image selection is now via InstaImagePickerHelper from create_post_screen
                          controller.getSelectedAssetFiles().then((files) async {
                            if (files.isEmpty) return;
                            Get.back();
                            Get.to(() => PostDataScreen(type: 'post', postImages: files));
                          });
                        }
                      },
                child: Text(
                  'Next',
                  style: TextStyles.semiBold(
                    20.sp,
                    fontColor: controller.selectedAssets.isEmpty ? AppColors.gray8C9499 : AppColors.primaryColor,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(CreatePostController controller) {
    return Obx(() {
      // No full-screen progress when switching types – show current grid or empty state
      if (controller.allAssets.isEmpty) {
        if (controller.isLoadingAssets.value) {
          return Center(
            child: Text('Loading...', style: TextStyles.medium(14.sp, fontColor: AppColors.gray8C9499)),
          );
        }
        // Permission not granted – show message and Allow access button
        if (!controller.isGalleryPermissionGranted.value) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No permission granted',
                    style: TextStyles.medium(16.sp, fontColor: AppColors.gray8C9499),
                    textAlign: TextAlign.center,
                  ),
                  Gap(20.h),
                  CommonButton(
                    padding: EdgeInsets.zero,
                    width: 150,
                    height: 45,
                    onPressed: () => openAppSettings(),
                    text: 'Allow access',
                  ),
                ],
              ),
            ),
          );
        }
        return Center(
          child: Text(
            'No ${controller.selectedAlbumType.value.toLowerCase()} found',
            style: TextStyles.medium(16.sp, fontColor: AppColors.gray8C9499),
          ),
        );
      }

      final assets = controller.allAssets;

      return GridView.builder(
        padding: EdgeInsets.all(4.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4.w,
          mainAxisSpacing: 4.w,
          childAspectRatio: 0.7,
        ),
        itemCount: assets.length,
        cacheExtent: 800,
        itemBuilder: (context, index) {
          final asset = assets[index];
          return _GalleryImageItem(asset: asset, controller: controller);
        },
      );
    });
  }
}

class _PopupMenuOverlay extends StatelessWidget {
  final Offset position;
  final Size size;
  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;
  final List<AssetPathEntity> albums;
  final void Function(AssetPathEntity) onAlbum;
  final VoidCallback onAll;
  final VoidCallback onDismiss;

  const _PopupMenuOverlay({
    required this.position,
    required this.size,
    required this.scaleAnimation,
    required this.opacityAnimation,
    required this.albums,
    required this.onAlbum,
    required this.onAll,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final menuWidth = 200.w;
    final itemHeight = 48.h;
    final maxMenuItems = 6;
    final menuHeight = (albums.isEmpty ? 1 : albums.length.clamp(1, maxMenuItems)) * itemHeight + 16.h;

    // Calculate position - center below the dropdown
    final leftPosition = (position.dx + size.width / 2) - (menuWidth / 2);
    // Ensure menu doesn't go off screen
    final adjustedLeft = leftPosition.clamp(16.w, screenWidth - menuWidth - 16.w);

    // Calculate if menu should appear above or below the button
    final spaceBelow = screenHeight - (position.dy + size.height);
    final spaceAbove = position.dy - safeAreaTop;
    final showAbove = spaceBelow < menuHeight + 32.h && spaceAbove > spaceBelow;

    // Position menu with proper spacing
    final topPosition = showAbove
        ? position.dy -
              menuHeight -
              8
                  .h // Above the button
        : position.dy + size.height + 8.h; // Below the button

    // Ensure menu doesn't go above safe area
    final adjustedTop = topPosition.clamp(safeAreaTop + 8.h, screenHeight - safeAreaBottom - menuHeight - 8.h);

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Menu
        Positioned(
          left: adjustedLeft,
          top: adjustedTop,
          child: AnimatedBuilder(
            animation: Listenable.merge([scaleAnimation, opacityAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: scaleAnimation.value,
                alignment: showAbove ? Alignment.bottomCenter : Alignment.topCenter,
                child: Opacity(
                  opacity: opacityAnimation.value,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: menuWidth,
                      decoration: BoxDecoration(
                        color: AppColors.whiteFFFFFF,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black000000.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 320.h),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (albums.isEmpty)
                                _MenuItem(label: 'All', onTap: onAll, isDestructive: false)
                              else
                                ...albums.map(
                                  (album) =>
                                      _MenuItem(label: album.name, onTap: () => onAlbum(album), isDestructive: false),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// In-memory thumbnail cache so scroll back doesn't reload thumbnails.
final Map<String, Uint8List> _thumbnailCache = {};

class _GalleryImageItem extends StatelessWidget {
  final AssetEntity asset;
  final CreatePostController controller;

  const _GalleryImageItem({required this.asset, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (asset.type == AssetType.video) {
          File? file = await asset.file;
          VideoPreviewBottomSheet.show(videoAsset: asset, videoFile: file);
        } else {
          controller.toggleAssetSelection(asset);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _ThumbnailWidget(asset: asset),
          Obx(() {
            final isSelected = controller.selectedAssets.contains(asset);
            return Positioned(
              top: 10,
              right: 10,
              child: CommonCheckBox(onChanged: (value) => controller.toggleAssetSelection(asset), value: isSelected),
            );
          }),
        ],
      ),
    );
  }
}

/// Loads thumbnail once and uses cache on rebuild (e.g. after scroll back).
class _ThumbnailWidget extends StatefulWidget {
  final AssetEntity asset;

  const _ThumbnailWidget({required this.asset});

  @override
  State<_ThumbnailWidget> createState() => _ThumbnailWidgetState();
}

class _ThumbnailWidgetState extends State<_ThumbnailWidget> {
  Future<Uint8List?>? _future;

  Future<Uint8List?> _loadAndCache() async {
    if (_thumbnailCache.containsKey(widget.asset.id)) {
      return _thumbnailCache[widget.asset.id];
    }
    try {
      final bytes = await widget.asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
      if (bytes != null) {
        _thumbnailCache[widget.asset.id] = bytes;
      }
      return bytes;
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cached = _thumbnailCache[widget.asset.id];
    if (cached != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(cached, fit: BoxFit.cover),
          if (widget.asset.type == AssetType.video)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(color: AppColors.black000000.withValues(alpha: 0.6), shape: BoxShape.circle),
                child: Icon(Icons.play_arrow, color: AppColors.whiteFFFFFF, size: 16.sp),
              ),
            ),
        ],
      );
    }
    _future ??= _loadAndCache();
    return FutureBuilder<Uint8List?>(
      key: ValueKey(widget.asset.id),
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(snapshot.data!, fit: BoxFit.cover),
              if (widget.asset.type == AssetType.video)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: AppColors.black000000.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow, color: AppColors.whiteFFFFFF, size: 16.sp),
                  ),
                ),
            ],
          );
        }
        return Container(
          color: AppColors.grayEDF1F4,
          child: Icon(
            widget.asset.type == AssetType.video ? Icons.videocam : Icons.image,
            color: AppColors.gray8C9499,
            size: 24.sp,
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;

  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({required this.label, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyles.semiBold(
                    14.sp,
                    fontColor: isDestructive ? AppColors.redFF5353 : AppColors.black2F3039,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

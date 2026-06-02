
import 'package:omeeba_new/presentation/main/dashboard/controller/dashboard_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/controller/reels_screen_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/views/reel_page.dart';
import 'package:omeeba_new/presentation/main/zeals/views/widgets/my_refresh_indicator.dart';


import '../../../../core/utils/exports.dart';

// ---------------------------------------------------------------
// REELS SCREEN (PAGEVIEW)
// ---------------------------------------------------------------
class ReelsScreen extends StatefulWidget {



  const ReelsScreen({
    super.key,


  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late final ReelsScreenController controller;
  final DashboardController _dashboardController = Get.find<DashboardController>();

  static const int _zealsTabIndex = 3;
  bool _wasOnZealsTab = false;

  // @override
  // void initState() {
  //   super.initState();
  //   _pageController = PageController();
  //   zeelController.initializeVideos();
  //   WidgetsBinding.instance.addObserver(this);
  //
  //   // Check initial tab index - if not on Zeals tab, ensure videos are paused
  //   _wasOnZealsTab = _dashboardController.currentIndex.value == _zealsTabIndex;
  //   if (!_wasOnZealsTab) {
  //     // Not on Zeals tab initially, pause all videos
  //     Future.microtask(() => _pauseAllVideos());
  //   }
  //
  //   // Listen to tab changes and pause/resume videos accordingly
  //   ever(_dashboardController.currentIndex, (index) {
  //     if (index != _zealsTabIndex) {
  //       _wasOnZealsTab = false;
  //       _pauseAllVideos();
  //     } else if (!_wasOnZealsTab) {
  //       // Coming back to Zeals tab - resume current video
  //       _wasOnZealsTab = true;
  //       _resumeCurrentVideo();
  //     }
  //   });
  // }
  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   super.didChangeAppLifecycleState(state);
  //   if (state == AppLifecycleState.paused ||
  //       state == AppLifecycleState.inactive ||
  //       state == AppLifecycleState.detached) {
  //     _pauseAllVideos();
  //   } else if (state == AppLifecycleState.resumed) {
  //     // App came back to foreground - resume current video if on Zeals tab
  //     if (_dashboardController.currentIndex.value == _zealsTabIndex) {
  //       _resumeCurrentVideo();
  //     }
  //   }
  // }
  // @override
  // void dispose() {
  //   WidgetsBinding.instance.removeObserver(this);
  //   _pageController.dispose();
  //   zeelController.disposeAllVideos();
  //   // Pause all videos before disposing
  //   _pauseAllVideos();
  //   super.dispose();
  // }


  @override
  void initState() {
    super.initState();
    controller = Get.put(
      ReelsScreenController(),
      tag: '${DateTime.now().millisecondsSinceEpoch}',
    );

    WidgetsBinding.instance.addObserver(this);

    // Check initial tab index - if not on Zeals tab, ensure videos are paused
    _wasOnZealsTab = _dashboardController.currentIndex.value == _zealsTabIndex;
    if (!_wasOnZealsTab) {
      // Not on Zeals tab initially, pause all videos
      Future.microtask(() => controller.pauseAllVideos());
    } else {
      // On Zeals tab initially - initialize videos
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.initFirstPlayers();
      });
    }

    // Listen to tab changes and pause/resume videos accordingly
    ever(_dashboardController.currentIndex, (index) {
      if (index != _zealsTabIndex) {
        _wasOnZealsTab = false;
        // Immediately pause all videos when leaving tab
        controller.pauseAllVideos();
      } else if (!_wasOnZealsTab) {
        // Coming back to Zeals tab - initialize videos if not already done, then resume current video
        _wasOnZealsTab = true;

        // Use postFrameCallback to ensure widget tree is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Double-check we're still on Zeals tab
          if (_dashboardController.currentIndex.value != _zealsTabIndex) {
            return;
          }

          // Initialize videos if not already initialized
          if (controller.reels.isNotEmpty) {
            controller.initFirstPlayers().then((_) {
              // After initialization completes, check again and resume
              if (_dashboardController.currentIndex.value == _zealsTabIndex) {
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (_dashboardController.currentIndex.value == _zealsTabIndex) {
                    controller.resumeCurrentVideo();
                  }
                });
              }
            }).catchError((e) {
              debugPrint('❌ Error initializing videos: $e');
            });
          } else {
            // No reels, just try to resume if there's a current video
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_dashboardController.currentIndex.value == _zealsTabIndex) {
                controller.resumeCurrentVideo();
              }
            });
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      controller.pauseAllVideos();
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground - resume current video if on Zeals tab
      if (_dashboardController.currentIndex.value == _zealsTabIndex) {
        controller.resumeCurrentVideo();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Controllers are disposed in ReelsScreenController.onClose()
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black000000,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: MyRefreshIndicator(
                  onRefresh: () async {
                    // await controller.handleRefresh(widget.onRefresh);
                  },
                  // shouldRefresh: widget.onRefresh != null,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [



                     PageView.builder(
                          controller: controller.pageController,
                          physics: const CustomPageViewScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          itemCount: controller.reels.length,

                          onPageChanged: controller.onPageChanged,
                          // itemCount: zeelController.reels.length,
                          // onPageChanged: (index) {
                          //   zeelController.onPageChanged(index);
                          // },
                          itemBuilder: (context, index) {
                            return
                            //   Obx(
                            //       () => ReelItem(
                            //     reel: zeelController.reels[index],
                            //     index: index,
                            //     isCurrentPage: index == zeelController.currentIndex.value,
                            //     onControllerCreated: (controller) => _registerVideoController(index, controller),
                            //   ),
                            // );
                            ReelPage(
                              reelData: controller.reels[index],
                              reelIndex: index,
                              autoPlay: index == controller.currentIndex.value,
                              likeKey: GlobalKey(),
                              reelsScreenController: controller,
                              onUpdateReelData: controller.onUpdateReelData,

                            );
                          },
                        ),

                      // HashTagAndMentionUserView(helper: controller.commentHelper),
                    ],
                  ),
                ),
              ),
              // ReelsTextField(controller: controller),
            ],
          ),

          // ReelsTopBar(controller: controller, widget: widget.widget),
        ],
      ),
    );
  }
}

class CustomPageViewScrollPhysics extends ScrollPhysics {
  const CustomPageViewScrollPhysics({super.parent});

  @override
  CustomPageViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomPageViewScrollPhysics(parent: buildParent(ancestor)!);
  }

  @override
  SpringDescription get spring => const SpringDescription(mass: 1, stiffness: 1000, damping: 60);
}

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:omeeba_new/presentation/main/create_post/controller/create_post_controller.dart';

import '../../../../core/utils/exports.dart';

class MusicWaveSlider extends StatelessWidget {
  final int audioDuration;
  final int videoDuration;
  final CreatePostController controller;

  const MusicWaveSlider({super.key, required this.audioDuration, required this.videoDuration, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,

      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Container(
                width: controller.boxWidth,
                height: 50,
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(5)),
                  gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryColor]),
                ),
              ),
              SizedBox(

                width: controller.boxWidth,
                height: 50,
                child: FittedBox(
                  fit: BoxFit.none,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.centerRight,
                      width: (controller.boxWidth - controller.borderWidth),
                      height: (50 - controller.borderWidth),
                      child: FittedBox(
                        fit: BoxFit.none,
                        child: Obx(() {
                          return AnimatedContainer(
                            duration: Duration(milliseconds: controller.currentProgress.value == 0.0 ? 0 : 1),
                            // Adjust speed as needed
                            curve: Curves.easeInOut,
                            // Smooth transition
                            width: max(
                              0,
                              (controller.boxWidth - controller.borderWidth) * (1 - controller.currentProgress.value),
                            ),
                            // Prevent negative width
                            height: (50 - controller.borderWidth),
                            color: Colors.white,
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SingleChildScrollView(

            controller: controller.scrollController,
            dragStartBehavior: DragStartBehavior.down,
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: (MediaQuery.of(context).size.width / 2) - (controller.boxWidth / 2), height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: controller.boxWidth),
                  child: Obx(
                        () => Row(
                      children: List.generate(controller.waves.length, (index) {
                        return Container(
                          height: index % 2 == 0 ? 20 : 12,
                          margin: EdgeInsets.symmetric(horizontal: controller.barHorizontalMargin),
                          width: controller.barWidth,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: AppColors.grayE7EBEE,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                SizedBox(width: (MediaQuery.of(context).size.width / 2) - (controller.boxWidth / 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
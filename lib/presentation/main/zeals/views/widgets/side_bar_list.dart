import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:omeeba_new/core/widgets/press_scale_button.dart';
import 'package:omeeba_new/presentation/main/zeals/controller/reel_page_controller.dart';
import 'package:omeeba_new/presentation/main/zeals/models/post_model.dart';

class SideBarList extends StatelessWidget {
  final ReelController controller;
  final GlobalKey likeKey;

  const SideBarList(
      {super.key, required this.controller, required this.likeKey});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Post reel = controller.reelData.value;
      final isPlaceholder = reel.id == -1;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [

            IconWithLabel(
                likeKey: likeKey,
                onTap: () {

                },
                image: (reel.isLiked ?? false)
                    ? Icon(Icons.favorite, color: Colors.white,)
                    :  Icon(Icons.favorite_border, color: Colors.white,),
                text: isPlaceholder ? '1' : (reel.likes ?? 0).toString()),
            if (reel.canComment == 1)
              IconWithLabel(
                onTap:  () {} ,
                image: Icon(Icons.comment, color: Colors.white,),
                text: isPlaceholder ? '1' : (reel.comments ?? 0).toString(),
              ),
            IconWithLabel(
              onTap:  () {},
              image: (reel.isSaved ?? false)
                  ? Icon(Icons.save, color: Colors.white,)
                  : Icon(Icons.download, color: Colors.white,),
              text: isPlaceholder ? '1' : (reel.saves ?? 0).toString(),
              iconColor: Colors.white,
            ),
            IconWithLabel(
              onTap: () {},
              image: Icon(Icons.share, color: Colors.white,),
              text: isPlaceholder ? '1' : (reel.shares ?? 0).toString(),
            ),


          ],
        ),
      );
    });
  }
}




class IconWithLabel extends StatelessWidget {
  final VoidCallback onTap;
  final Icon image;
  final String text;
  final Color? iconColor;
  final Key? likeKey;

  const IconWithLabel({
    super.key,
    required this.onTap,
    required this.image,
    required this.text,
    this.iconColor,
    this.likeKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.5),
      child: Column(
        children: [
          PressScaleButton(
            onTap: onTap,
            child: KeyedSubtree(
              key: likeKey,
              child: image,
            ),
          ),
          if (text.isNotEmpty)
            Text(
              text,
              style: TextStyle(
                      fontSize: 13, color: Colors.white)
                  .copyWith(
                shadows: <Shadow>[
                  Shadow(
                    offset: const Offset(0.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.grey,
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}

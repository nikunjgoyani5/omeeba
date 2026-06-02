import 'package:flutter/material.dart';
import 'package:omeeba_new/presentation/main/zeals/views/widgets/style_res.dart';


class GradientIcon extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;

  const GradientIcon({super.key, required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return (gradient ?? StyleRes.themeGradient).createShader(bounds);
      },
      blendMode: BlendMode.srcATop,
      child: child,
    );
  }
}

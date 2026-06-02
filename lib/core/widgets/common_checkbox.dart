import 'package:flutter/material.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';


class CommonCheckBox extends StatelessWidget {
  const CommonCheckBox({super.key, required this.onChanged, required this.value,  this.radius, this.borderColor});
  final ValueChanged<bool?> onChanged;
  final bool value ;
  final double? radius ;
  final Color? borderColor ;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      width: 20,
      child: Checkbox(
        value: value,
        onChanged:onChanged,
        side: BorderSide(color: borderColor??AppColors.grey949597),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius??3), // Rounded checkbox
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:omeeba_new/core/theme/app_colors.dart';
import 'package:omeeba_new/core/theme/text_styles.dart';

class CommonTextField extends StatefulWidget {
  const CommonTextField({
    super.key,
    required this.hintText,
    required this.controller,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.onSubmitted,
    this.borderColor,
    this.textAlign,
    this.hintColor,
    this.onChanged,
    this.validator,
    this.inputFormatters,
    this.height,
    this.autofocus = false,
    this.readOnly = false,
    this.expands = false,
    this.radius,
    this.cursorColor,
    this.maxLines = 1,
    this.minLines = 1,
    this.focusNode,
    this.fillColor,
    this.onTap,
    this.errorBorderSide,
    this.focusedErrorBorderSide,
    this.textStyle,
    this.labelText,
    this.textFieldAlignment,
    this.textFieldPadding,
    this.textInputAction,
    this.errorText,
    this.textAlignVertical,
  });

  final String? labelText;
  final String hintText;
  final int? maxLength;
  final TextEditingController controller;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final double? height;
  final bool autofocus;
  final bool readOnly;
  final bool expands;
  final BorderRadius? radius;
  final TextAlign? textAlign;
  final Alignment? textFieldAlignment;
  final int? maxLines;
  final TextStyle? textStyle;
  final int? minLines;
  final FocusNode? focusNode;
  final Color? fillColor;
  final Color? hintColor;
  final Color? cursorColor;
  final Color? borderColor;
  final void Function()? onTap;
  final BorderSide? errorBorderSide;
  final BorderSide? focusedErrorBorderSide;
  final EdgeInsetsGeometry? textFieldPadding;
  final TextInputAction? textInputAction;
  final String? errorText;
  final TextAlignVertical? textAlignVertical;

  @override
  State<CommonTextField> createState() => _CommonTextFieldState();
}

class _CommonTextFieldState extends State<CommonTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFocused = _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.fillColor ?? AppColors.whiteFFFFFF,
            borderRadius: widget.radius ?? BorderRadius.circular(10.r),
            border: Border.all(
              color: widget.errorText?.isNotEmpty ?? false
                  ? AppColors.redFF5353
                  : isFocused && widget.readOnly == false
                  ? AppColors.black2F3039
                  : widget.borderColor ?? AppColors.gray8C9499.withValues(alpha: 0.40),
              width: 1,
            ),
          ),
          child: Padding(
            padding: widget.textFieldPadding ?? EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TextFormField(
                onTapOutside: (V) {
                  FocusScope.of(context).unfocus();
                },
                textAlign: widget.textAlign ?? TextAlign.left,
                focusNode: _focusNode,
                maxLength: widget.maxLength,
                maxLines: widget.maxLines,
                minLines: widget.minLines,
                expands: widget.expands,
                readOnly: widget.readOnly,
                onTap: widget.onTap,
                autofocus: widget.autofocus,
                inputFormatters: widget.inputFormatters,
                onChanged: widget.onChanged,
                // validator: widget.validator,
                obscureText: widget.obscureText,
                onFieldSubmitted: widget.onSubmitted,
                keyboardType: widget.keyboardType,
                controller: widget.controller,
                cursorColor: widget.cursorColor ?? AppColors.primaryColor,
                textInputAction: widget.textInputAction ?? TextInputAction.done,
                textAlignVertical: widget.textAlignVertical ?? TextAlignVertical.center,
                style: widget.textStyle ?? TextStyles.medium(16.sp),
                cursorHeight: 20.h,
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: widget.prefixIcon,
                  suffixIcon: widget.suffixIcon != null
                      ? SizedBox(height: 24, width: 24, child: Center(child: widget.suffixIcon))
                      : null,
                  border: InputBorder.none,
                  filled: true,
                  fillColor: widget.fillColor ?? AppColors.whiteFFFFFF,
                  labelText: widget.labelText,
                  alignLabelWithHint: (widget.maxLines ?? 1) > 1,
                  labelStyle: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499),
                  // hintText: widget.hintText,
                  hintStyle: TextStyles.regular(16.sp, fontColor: AppColors.gray8C9499),
                ),
              ),
            ),
          ),
        ),
        if (widget.errorText?.isNotEmpty ?? false) ...[
          Gap(5),
          Text(widget.errorText ?? '', style: TextStyles.regular(12.sp, fontColor: AppColors.redFF5353)),
        ],
      ],
    );
  }
}
class CommonSearchTextField extends StatelessWidget {
  const CommonSearchTextField({
    super.key,
    required this.hintText,
    required this.controller,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.onSubmitted,
    this.borderColor,
    this.textAlign,
    this.hintColor,
    this.onChanged,
    this.validator,
    this.inputFormatters,
    this.height,
    this.autofocus = false,
    this.readOnly = false,
    this.expands = false,
    this.radius,

    this.focusNode,
    this.cursorColor,
    this.fillColor,
    this.onTap,
    this.errorBorderSide,
    this.focusedErrorBorderSide,
    this.textInputAction,
    this.textCapitalization,
    this.textStyle,
    this.maxLine = 1,
  });

  final String hintText;
  final int? maxLength;
  final int? maxLine;
  final TextEditingController controller;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextCapitalization? textCapitalization;
  final bool obscureText;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final double? height;
  final bool autofocus;
  final bool readOnly;
  final bool expands;
  final BorderRadius? radius;
  final TextAlign? textAlign;
  final TextStyle? textStyle;

  final FocusNode? focusNode;
  final Color? fillColor;
  final Color? hintColor;
  final Color? borderColor;
  final Color? cursorColor;
  final void Function()? onTap;
  final BorderSide? errorBorderSide;
  final BorderSide? focusedErrorBorderSide;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 50),
      child: TextFormField(
        textAlign: textAlign ?? TextAlign.left,
        focusNode: focusNode,
        maxLength: maxLength,
        maxLines: maxLine,
        expands: expands,
        readOnly: readOnly,
        onTap: onTap,
        autofocus: autofocus,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        obscureText: obscureText,
        onFieldSubmitted: onSubmitted,
        keyboardType: keyboardType,
        controller: controller,
        cursorColor: cursorColor ?? AppColors.primaryColor,
        textInputAction: textInputAction ?? TextInputAction.done,
        textCapitalization: textCapitalization != null
            ? textCapitalization!
            : keyboardType == TextInputType.emailAddress
            ? TextCapitalization.none
            : TextCapitalization.sentences,
        textAlignVertical: TextAlignVertical.top,
        style: textStyle ?? TextStyles.medium(16.sp),
        decoration: InputDecoration(


            fillColor: fillColor ?? AppColors.grayEDF1F4,
            filled:  true,
            counterText: '',
            hintText: hintText,
            hintStyle: TextStyles.medium(16.sp, fontColor: AppColors.gray707070),
            prefixIcon: prefixIcon != null ? SizedBox(height: 24, width: 24, child: Center(child: prefixIcon)) : null,
            suffixIcon: suffixIcon != null ? SizedBox(height: 24, width: 24, child: Center(child: suffixIcon)) : null,

            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent,
                  width: 0),borderRadius: BorderRadius.circular(500),
            ),
            disabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent,
                  width: 0),borderRadius: BorderRadius.circular(500),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent,
                  width: 0),borderRadius: BorderRadius.circular(500),
            ),errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.transparent,
              width: 0),borderRadius: BorderRadius.circular(500),
        ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent,
                  width: 0),borderRadius: BorderRadius.circular(500),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent,
                  width: 0),borderRadius: BorderRadius.circular(500),
            )
,
contentPadding: EdgeInsetsGeometry.only(top: 15),
        ),
      ),
    );
  }
}
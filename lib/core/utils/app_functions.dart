import 'package:fluttertoast/fluttertoast.dart';
import 'package:fluttertoast/fluttertoast.dart' as ftoast;

import 'exports.dart';

class AppFunctions {
  showToast(String msg, {Color? textColor, Color? bgColor}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: bgColor ?? Colors.black,
      textColor: textColor ?? Colors.white,
      fontSize: 16.0,
    );
  }

  void closeKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  static void showCustomToast(BuildContext context, {required String message, required bool isSuccess}) {
    final fToast = ftoast.FToast();
    fToast.init(context);

    Widget toast = Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isSuccess ? AppColors.green : AppColors.red,
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isSuccess
              ? Icon(Icons.check, color: AppColors.white)
              : Icon(Icons.warning_amber_rounded, color: AppColors.white),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(message, style: TextStyles.semiBold(14.sp, fontColor: Colors.white)),
          ),
        ],
      ),
    );

    fToast.showToast(child: toast, gravity: ToastGravity.BOTTOM, toastDuration: const Duration(seconds: 3));
  }

  // static void showCustomErrorPopUp(BuildContext context, {required String message}) {
  //   Widget popup = Container(
  //     width: Get.width * 0.8,
  //     padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
  //     decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(30.r)),
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Text(message, style: TextStyles.medium(14)),
  //         Gap(20),
  //         TextButton(
  //           onPressed: () {
  //             Get.back();
  //           },
  //           child: Text('Ok', style: TextStyles.bold(18),),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  static void showCustomErrorPopUp(BuildContext context, {required String title, required String message}) {
    FocusScope.of(context).requestFocus(FocusNode());
    Get.dialog(
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: Get.width * 0.9,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: AppColors.white,
              // borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyles.bold(17.sp), textAlign: TextAlign.start),
                Gap(10),
                Text(message, style: TextStyles.medium(15.sp), textAlign: TextAlign.start),
                Gap(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Spacer(),
                 TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        child: Text('OK', style: TextStyles.bold(15.sp, fontColor: AppColors.primaryColor)),
                      ),

                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}

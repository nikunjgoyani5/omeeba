import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:omeeba_new/core/services/onesignal_notification_service.dart';
import 'package:omeeba_new/core/utils/app_prefrence.dart';

import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/routes/zeals_pause_observer.dart';
import 'core/services/app_info_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    final exceptionText = details.exceptionAsString();
    final isKnownPickerThumbnailError =
        exceptionText.contains('Thumbnail request error') ||
        exceptionText.contains('setDataSource failed: status = 0x80000000');
    if (isKnownPickerThumbnailError) {
      // wechat_assets_picker can emit non-fatal thumbnail errors for invalid
      // media store entries on some Android devices. Ignore only this case.
      return;
    }
    FlutterError.presentError(details);
  };
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  PrefService.init();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await AppInfoService.instance.init();
  await OneSignalNotificationService. initialize();
  await DeepLinkService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return GetMaterialApp(
            title: 'Omeeba',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            initialRoute: AppRoutes.initial,
            getPages: AppPages.pages,
            navigatorObservers: [ZealsPauseObserver()],
            defaultTransition: Transition.cupertino,
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
    );
  }
}

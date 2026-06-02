import 'package:get/get.dart';
import 'package:omeeba_new/presentation/auth/views/signup_screen.dart';
import 'package:omeeba_new/presentation/main/chat/bindings/chat_binding.dart';
import 'package:omeeba_new/presentation/main/chat/bindings/chat_details_binding.dart';
import 'package:omeeba_new/presentation/main/chat/views/chat_details_screen.dart';
import 'package:omeeba_new/presentation/main/chat/views/chat_screen.dart';
import 'package:omeeba_new/presentation/main/explore/bindings/explore_binding.dart';
import 'package:omeeba_new/presentation/main/explore/views/explore_view.dart';
import 'package:omeeba_new/presentation/main/other_user_profile/views/other_user_profile_view.dart';
import 'package:omeeba_new/presentation/main/settings/bindings/settings_binding.dart';
import 'package:omeeba_new/presentation/main/settings/views/setting_screen.dart';
import 'package:omeeba_new/presentation/main/create_post/bindings/create_post_binding.dart';
import 'package:omeeba_new/presentation/main/create_post/views/create_post_screen.dart';
import 'package:omeeba_new/presentation/main/contact_us/bindings/contact_us_binding.dart';
import 'package:omeeba_new/presentation/main/contact_us/views/contact_us_screen.dart';

import '../../presentation/auth/bindings/auth_binding.dart';
import '../../presentation/auth/views/forgot_password_screen.dart';
import '../../presentation/auth/views/login_screen.dart';
import '../../presentation/main/dashboard/bindings/dashboard_binding.dart';
import '../../presentation/main/dashboard/views/dashboard_screen.dart';
import '../../presentation/main/other_user_profile/bindings/other_user_profile_bimding.dart';
import '../../presentation/main/notification/views/post_content_detail_screen.dart';
import '../../presentation/onboard/splash/bindings/splash_binding.dart';
import '../../presentation/onboard/splash/views/splash_screen.dart';
import 'app_routes.dart';

class AppPages {
  static final List<GetPage> pages = [
    // Splash Screen
    GetPage(name: AppRoutes.initial, page: () => const SplashScreen(), binding: SplashBinding()),
    // Login Screen
    GetPage(name: AppRoutes.login, page: () => const LoginScreen(), binding: AuthBinding()),
    // Dashboard Screen
    GetPage(name: AppRoutes.dashboard, page: () => const DashboardScreen(), binding: DashboardBinding()),
    GetPage(name: AppRoutes.setting, page: () => const SettingScreen(), binding: SettingsBinding()),
    GetPage(name: AppRoutes.signUp, page: () => const SignupScreen(), binding: AuthBinding()),
    GetPage(name: AppRoutes.forgotPassword, page: () => const ForgotPasswordScreen(formSetting: true,), binding: AuthBinding()),
    GetPage(name: AppRoutes.chat, page: () => ChatScreen(), binding: ChatBinding()),
    GetPage(name: AppRoutes.chatDetails, page: () => const ChatDetailsScreen(), binding: ChatDetailsBinding()),
    GetPage(name: AppRoutes.contactUs, page: () => const ContactUsScreen(), binding: ContactUsBinding()),
    GetPage(name: AppRoutes.postContentDetail, page: () =>  PostContentDetailScreen(), binding: PostContentDetailBinding()),
    GetPage(name: AppRoutes.explore, page: () => const ExploreView(), binding: ExploreBinding()),
    GetPage(
      name: AppRoutes.otherUserProfile,
      page: () {
        final args = Get.arguments;
        final userId = args is String
            ? args
            : args is Map
            ? args['userId']?.toString() ?? ''
            : '';
        return OtherUserProfileView(controllerTag: 'other_user_profile_$userId');
      },
      binding: OtherUserProfileBinding(),
    ),
    GetPage(name: AppRoutes.createPost, page: () => const CreatePostScreen(), binding: CreatePostBinding()),
  ];
}

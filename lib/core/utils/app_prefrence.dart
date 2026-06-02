import 'package:shared_preferences/shared_preferences.dart';

class PrefService {
  static late SharedPreferences _pref;

  static init() async {
    _pref = await SharedPreferences.getInstance();
  }



  static setValue(String key, value) async {
    if (value is String) {
      await _pref.setString(key, value);
    } else if (value is int) {
      await _pref.setInt(key, value);
    } else if (value is double) {
      await _pref.setDouble(key, value);
    } else if (value is bool) {
      await _pref.setBool(key, value);
    } else if (value is List<String>) {
      await _pref.setStringList(key, value);
    }
  }

  static String getString(String key) {
    return _pref.getString(key) ?? '';
  }

  static int getInt(String key) {
    return _pref.getInt(key) ?? 0;
  }

  static double getDouble(String key) {
    return _pref.getDouble(key) ?? 0.0;
  }

  static bool getBool(String key) {
    return _pref.getBool(key) ?? false;
  }

  static List<String> getStringList(String key) {
    return _pref.getStringList(key) ?? [];
  }

  static clear() async {
    await _pref.clear();
  }

  static singlclear(String key) async {
    await _pref.remove(key);
  }
}
class PrefKeys {
  static const String accessToken = "accessToken";
  static const String isLogin = "isLogin";
  static const String userId = "userId";
  static const String userName = "userName";
  static const String name = "name";
  static const String isVerifiedBeach = "isVerifiedBeach";
  static const String userProfile = "userProfile";
  static const String userEmail = "userEmail";
  static const String userPhone = "userPhone";

  static const String oneSignalId = "oneSignalId";

  static const String oneSignalSubscriptionId = "oneSignalSubscriptionId";


}

import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  static const String _keyUserId = "user_id_pref";
  static const String _keyUserLevel = "user_level_pref";
  static const String _keyHasSeenOnboarding = "seenOnboarding";
  static const String _keyFullName = "fullname";
  static const String _keyEmail = "email";

  /// Save user login details
  static Future<void> saveUserLogin(String userIdString, String storedUserLevel, String storedFullName, String storedEmail) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userIdString);
    await prefs.setString(_keyUserLevel, storedUserLevel);
    await prefs.setString(_keyFullName, storedFullName);
    await prefs.setString(_keyEmail, storedEmail);
  }

  /// Retrieve user login details
  static Future<Map<String, String?>> getUserLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      "user_id_pref": prefs.getString(_keyUserId),
      "user_level_pref": prefs.getString(_keyUserLevel),
      "fullname": prefs.getString(_keyFullName),
      "email": prefs.getString(_keyEmail)
    };
  }

  /// Save onboarding status
  static Future<void> setOnboardingSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, true);
  }

  /// Check if user has seen onboarding
  static Future<bool> hasSeenOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  /// Clear user data (for logout)
  static Future<void> clearUserData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

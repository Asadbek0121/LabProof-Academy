import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_language.dart';

class AppPreferencesService {
  const AppPreferencesService._();

  static const _studentLanguageKey = 'student_language';

  static Future<AppLanguage> loadStudentLanguage() async {
    final preferences = await SharedPreferences.getInstance();
    final storedValue = preferences.getString(_studentLanguageKey);
    return AppLanguageX.fromStorageValue(storedValue);
  }

  static Future<void> saveStudentLanguage(AppLanguage language) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_studentLanguageKey, language.storageValue);
  }
}

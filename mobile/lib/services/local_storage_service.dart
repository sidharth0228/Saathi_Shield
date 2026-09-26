import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _boxName = 'saathi_shield_local_box';
  static const String _darkModeKey = 'is_dark_mode';
  static const String _userCacheKey = 'cached_user_profile';
  static const String _notificationsKey = 'saved_notifications';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  // Dark Mode preferences
  bool isDarkMode() {
    return _box.get(_darkModeKey, defaultValue: false) as bool;
  }

  Future<void> setDarkMode(bool value) async {
    await _box.put(_darkModeKey, value);
  }

  // Cached User JSON management
  String? getCachedUserJson() {
    return _box.get(_userCacheKey) as String?;
  }

  Future<void> cacheUserJson(String jsonStr) async {
    await _box.put(_userCacheKey, jsonStr);
  }

  Future<void> clearUserCache() async {
    await _box.delete(_userCacheKey);
  }

  // Notifications JSON management
  String? getNotificationsJson() {
    return _box.get(_notificationsKey) as String?;
  }

  Future<void> cacheNotificationsJson(String jsonStr) async {
    await _box.put(_notificationsKey, jsonStr);
  }

  Future<void> clearNotificationsCache() async {
    await _box.delete(_notificationsKey);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}

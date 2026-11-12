import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../models/subscriber_model.dart';
import '../../models/location_record_model.dart';
import '../../models/speed_test_result_model.dart';
import '../../models/notification_model.dart';
import '../../models/notification_preferences_model.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Theme Mode
  static bool get isDarkMode => _prefs?.getBool(AppConstants.prefIsDarkMode) ?? false;
  static Future<void> setDarkMode(bool value) async {
    await _prefs?.setBool(AppConstants.prefIsDarkMode, value);
  }

  // Tracking Active
  static bool get isTrackingActive => _prefs?.getBool(AppConstants.prefLocationTrackingActive) ?? false;
  static Future<void> setTrackingActive(bool value) async {
    await _prefs?.setBool(AppConstants.prefLocationTrackingActive, value);
  }

  // Notifications
  static bool get notificationsEnabled => _prefs?.getBool(AppConstants.prefNotificationsEnabled) ?? true;
  static Future<void> setNotificationsEnabled(bool value) async {
    await _prefs?.setBool(AppConstants.prefNotificationsEnabled, value);
  }

  // Poor Signal Alerts
  static bool get poorSignalAlerts => _prefs?.getBool(AppConstants.prefPoorSignalAlerts) ?? true;
  static Future<void> setPoorSignalAlerts(bool value) async {
    await _prefs?.setBool(AppConstants.prefPoorSignalAlerts, value);
  }

  // Cached Subscriber
  static SubscriberModel? getCachedSubscriber() {
    final raw = _prefs?.getString(AppConstants.prefCachedUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SubscriberModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCachedSubscriber(SubscriberModel subscriber) async {
    await _prefs?.setString(AppConstants.prefCachedUser, jsonEncode(subscriber.toMap()));
  }

  static Future<void> clearCachedSubscriber() async {
    await _prefs?.remove(AppConstants.prefCachedUser);
  }

  // Local Location History
  static List<LocationRecordModel> getLocalLocationHistory() {
    final raw = _prefs?.getStringList('roamease_location_history_cache') ?? [];
    return raw.map((item) {
      try {
        return LocationRecordModel.fromMap(jsonDecode(item));
      } catch (_) {
        return null;
      }
    }).whereType<LocationRecordModel>().toList();
  }

  static Future<void> saveLocalLocationRecord(LocationRecordModel record) async {
    final list = getLocalLocationHistory();
    list.insert(0, record);
    // Keep last 50
    final trimmed = list.take(50).map((r) => jsonEncode(r.toMap())).toList();
    await _prefs?.setStringList('roamease_location_history_cache', trimmed);
  }

  static Future<void> clearLocalLocationHistory() async {
    await _prefs?.remove('roamease_location_history_cache');
  }

  // Local Speed Test History
  static List<SpeedTestResultModel> getLocalSpeedTests() {
    final raw = _prefs?.getStringList('roamease_speed_history_cache') ?? [];
    return raw.map((item) {
      try {
        return SpeedTestResultModel.fromMap(jsonDecode(item));
      } catch (_) {
        return null;
      }
    }).whereType<SpeedTestResultModel>().toList();
  }

  static Future<void> saveLocalSpeedTest(SpeedTestResultModel test) async {
    final list = getLocalSpeedTests();
    list.insert(0, test);
    final trimmed = list.take(50).map((t) => jsonEncode(t.toMap())).toList();
    await _prefs?.setStringList('roamease_speed_history_cache', trimmed);
  }

  // --- NOTIFICATION MANAGEMENT CACHE ---
  static List<NotificationModel> getLocalNotifications() {
    final raw = _prefs?.getStringList(AppConstants.prefLocalNotificationsCache) ?? [];
    return raw.map((item) {
      try {
        return NotificationModel.fromMap(jsonDecode(item));
      } catch (_) {
        return null;
      }
    }).whereType<NotificationModel>().toList();
  }

  static Future<void> saveLocalNotifications(List<NotificationModel> list) async {
    final trimmed = list.take(100).map((n) => jsonEncode(n.toMap())).toList();
    await _prefs?.setStringList(AppConstants.prefLocalNotificationsCache, trimmed);
  }

  static Future<void> saveSingleLocalNotification(NotificationModel notification) async {
    final list = getLocalNotifications();
    list.removeWhere((n) => n.id == notification.id);
    list.insert(0, notification);
    await saveLocalNotifications(list);
  }

  static Future<void> clearLocalNotifications() async {
    await _prefs?.remove(AppConstants.prefLocalNotificationsCache);
  }

  // --- NOTIFICATION PREFERENCES CACHE ---
  static NotificationPreferencesModel getNotificationPreferences(String userId) {
    final raw = _prefs?.getString(AppConstants.prefNotificationPreferences);
    if (raw == null || raw.isEmpty) {
      return NotificationPreferencesModel.defaultPreferences(userId);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPreferencesModel.fromMap(map, userId: userId);
    } catch (_) {
      return NotificationPreferencesModel.defaultPreferences(userId);
    }
  }

  static Future<void> saveNotificationPreferences(NotificationPreferencesModel prefs) async {
    await _prefs?.setString(AppConstants.prefNotificationPreferences, jsonEncode(prefs.toMap()));
  }

  // --- OPENCELLID AUTHORIZED API KEY ---
  static String get openCellIdApiKey => _prefs?.getString(AppConstants.prefOpenCellIdApiKey) ?? '';
  static Future<void> setOpenCellIdApiKey(String key) async {
    await _prefs?.setString(AppConstants.prefOpenCellIdApiKey, key.trim());
  }
}

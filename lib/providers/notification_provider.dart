import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/notification_model.dart';
import '../../models/notification_preferences_model.dart';
import '../core/services/notification_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/firebase_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  NotificationPreferencesModel _preferences =
      NotificationPreferencesModel.defaultPreferences('guest');
  bool _isLoading = false;
  String _currentFilter = 'all';

  // State trackers to prevent duplicate alerts
  String? _lastNetworkType;
  bool? _lastIsConnected;
  bool? _lastIsRoaming;
  String? _lastCity;
  bool _alerted80Percent = false;
  bool _alerted100Percent = false;

  List<NotificationModel> get notifications {
    if (_currentFilter == 'unread') {
      return _notifications.where((n) => !n.isRead).toList();
    } else if (_currentFilter == 'network') {
      return _notifications.where((n) => n.category == NotificationCategory.network).toList();
    } else if (_currentFilter == 'roaming') {
      return _notifications.where((n) => n.category == NotificationCategory.roaming).toList();
    } else if (_currentFilter == 'location') {
      return _notifications.where((n) => n.category == NotificationCategory.location).toList();
    } else if (_currentFilter == 'dataUsage') {
      return _notifications.where((n) => n.category == NotificationCategory.dataUsage).toList();
    } else if (_currentFilter == 'security') {
      return _notifications.where((n) => n.category == NotificationCategory.security).toList();
    }
    return _notifications;
  }

  List<NotificationModel> get allNotifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  NotificationPreferencesModel get preferences => _preferences;
  bool get isLoading => _isLoading;
  String get currentFilter => _currentFilter;

  NotificationProvider() {
    _initLocal();
  }

  void _initLocal() {
    _notifications = StorageService.getLocalNotifications();
    _preferences = StorageService.getNotificationPreferences('guest');
    notifyListeners();
  }

  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  /// Synchronizes notifications and preferences with Cloud Firestore and registers FCM token
  Future<void> syncWithCloud(String userId) async {
    _isLoading = true;
    _preferences = StorageService.getNotificationPreferences(userId);
    notifyListeners();

    if (!FirebaseService.isInitialized) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // 1. Register FCM Push Token in subscriber profile
      final token = NotificationService.fcmToken;
      if (token != null && token.isNotEmpty) {
        await FirebaseService.saveFcmToken(userId, token);
      }

      // 2. Fetch Cloud Preferences
      final cloudPrefs = await FirebaseService.fetchNotificationPreferences(userId);
      if (cloudPrefs != null) {
        _preferences = cloudPrefs;
        await StorageService.saveNotificationPreferences(cloudPrefs);
      }

      // 3. Fetch Cloud Notification Records
      final cloudNotifications = await FirebaseService.fetchNotifications(userId);
      if (cloudNotifications.isNotEmpty) {
        _notifications = cloudNotifications;
        await StorageService.saveLocalNotifications(_notifications);
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  /// Internal dispatcher: verifies user preferences before triggering local alerts and persisting records
  Future<void> _dispatchNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationCategory category,
    String? actionRoute,
    Map<String, dynamic>? payload,
    required Future<void> Function() showLocalAlert,
  }) async {
    // Check if user disabled notifications globally
    if (!_preferences.allNotificationsEnabled) return;

    // Check category-specific user preference toggle
    switch (category) {
      case NotificationCategory.network:
        if (!_preferences.networkChanges) return;
        break;
      case NotificationCategory.roaming:
        if (!_preferences.roamingAlerts) return;
        break;
      case NotificationCategory.location:
        if (!_preferences.significantLocation) return;
        break;
      case NotificationCategory.dataUsage:
        if (!_preferences.dataUsageAlerts) return;
        break;
      case NotificationCategory.security:
        if (!_preferences.securityAlerts) return;
        break;
      case NotificationCategory.general:
        break;
    }

    // 1. Show Local Heads-up Notification
    await showLocalAlert();

    // 2. Create and Store Notification Model
    final record = NotificationModel(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      body: body,
      category: category,
      timestamp: DateTime.now(),
      isRead: false,
      actionRoute: actionRoute,
      payload: payload,
    );

    _notifications.insert(0, record);
    notifyListeners();

    // 3. Persist locally and to Cloud Firestore
    await StorageService.saveSingleLocalNotification(record);
    await FirebaseService.saveNotification(record);
  }

  // -------------------------------------------------------------
  // REAL EVENT TRIGGER HANDLERS (No Dummy Alerts)
  // -------------------------------------------------------------

  /// 1. Network type change between 4G and 5G
  Future<void> onNetworkTypeChanged({
    required String userId,
    required String currentType,
    required String operatorName,
  }) async {
    if (_lastNetworkType == null) {
      _lastNetworkType = currentType;
      return;
    }

    if (_lastNetworkType != currentType && currentType != 'Searching...' && currentType != 'No Signal') {
      final oldType = _lastNetworkType!;
      _lastNetworkType = currentType;

      final is5G = currentType.toUpperCase().contains('5G') || currentType.toUpperCase().contains('NR');
      final title = is5G ? '⚡ Switched to 5G Ultra-Wideband' : '📶 Switched to 4G LTE';
      final body = is5G
          ? 'Connected to high-speed 5G network ($currentType) on $operatorName.'
          : 'Network transitioned from $oldType to $currentType on $operatorName.';

      await _dispatchNotification(
        userId: userId,
        title: title,
        body: body,
        category: NotificationCategory.network,
        showLocalAlert: () => NotificationService.showNetworkTransitionNotification(
          oldType: oldType,
          newType: currentType,
          operator: operatorName,
        ),
      );
    }
  }

  /// 2. Connection state lost or restored
  Future<void> onConnectionStateChanged({
    required String userId,
    required bool isConnected,
    required String operatorName,
    required String networkType,
  }) async {
    if (_lastIsConnected == null) {
      _lastIsConnected = isConnected;
      return;
    }

    if (_lastIsConnected != isConnected) {
      _lastIsConnected = isConnected;

      final title = isConnected ? '✅ Cellular Connection Restored' : '⚠️ Cellular Connection Lost';
      final body = isConnected
          ? 'Reconnected to $operatorName ($networkType). Roaming and mobile telemetry resumed.'
          : 'Cellular carrier signal disconnected. Searching for available cellular base stations.';

      await _dispatchNotification(
        userId: userId,
        title: title,
        body: body,
        category: NotificationCategory.network,
        showLocalAlert: () => NotificationService.showConnectionStatusNotification(
          isConnected: isConnected,
          operator: operatorName,
          type: networkType,
        ),
      );
    }
  }

  /// 3. Poor signal strength alert (< -110 dBm)
  Future<void> onPoorSignalDetected({
    required String userId,
    required int dbm,
    required String operatorName,
  }) async {
    if (!_preferences.poorSignal) return;

    final title = '⚠️ Poor Signal Alert ($dbm dBm)';
    final body = 'Cellular signal strength is degraded ($dbm dBm) on $operatorName. Call handover or packet loss may occur.';

    await _dispatchNotification(
      userId: userId,
      title: title,
      body: body,
      category: NotificationCategory.network,
      showLocalAlert: () => NotificationService.showPoorSignalAlert(
        dbm: dbm,
        operatorName: operatorName,
      ),
    );
  }

  /// 4. Roaming status change
  Future<void> onRoamingStatusChanged({
    required String userId,
    required bool isRoaming,
    required String operatorName,
    String? countryIso,
  }) async {
    if (_lastIsRoaming == null) {
      _lastIsRoaming = isRoaming;
      return;
    }

    if (_lastIsRoaming != isRoaming) {
      _lastIsRoaming = isRoaming;

      final title = isRoaming ? '🌐 Roaming Network Active' : '🏠 Home Carrier Connected';
      final body = isRoaming
          ? 'You are now roaming on partner network $operatorName. International roaming data rates apply.'
          : 'Returned to primary home network operator ($operatorName). Standard domestic tariff restored.';

      await _dispatchNotification(
        userId: userId,
        title: title,
        body: body,
        category: NotificationCategory.roaming,
        showLocalAlert: () => NotificationService.showRoamingAlert(
          operatorName: operatorName,
          isRoaming: isRoaming,
          countryIso: countryIso,
        ),
      );
    }
  }

  /// 5. Significant location change (with user consent)
  Future<void> onSignificantLocationChanged({
    required String userId,
    required String city,
    required String area,
    required bool userConsent,
  }) async {
    if (!userConsent || city.isEmpty || city == 'Current Location' || city == 'Detecting...') {
      return;
    }

    if (_lastCity == null) {
      _lastCity = city;
      return;
    }

    if (_lastCity != city) {
      _lastCity = city;

      final title = '📍 Significant Location Change';
      final body = 'Entered $city, $area. Local cell towers and regional roaming boundaries updated.';

      await _dispatchNotification(
        userId: userId,
        title: title,
        body: body,
        category: NotificationCategory.location,
        showLocalAlert: () => NotificationService.showSignificantLocationNotification(
          city: city,
          area: area,
        ),
      );
    }
  }

  /// 6. Data usage tracking (80% and 100% threshold alerts)
  Future<void> recordDataUsage({
    required String userId,
    required double additionalMb,
  }) async {
    final updatedUsageMb = _preferences.currentDataUsedMb + additionalMb;
    _preferences = _preferences.copyWith(currentDataUsedMb: updatedUsageMb);
    notifyListeners();

    await StorageService.saveNotificationPreferences(_preferences);
    await FirebaseService.saveNotificationPreferences(_preferences);

    final limitMb = _preferences.dataLimitGb * 1024.0;
    if (limitMb <= 0) return;

    final usageRatio = updatedUsageMb / limitMb;
    final usedGb = updatedUsageMb / 1024.0;
    final limitGb = _preferences.dataLimitGb;

    // 80% Threshold Alert
    if (usageRatio >= 0.80 && usageRatio < 1.0 && !_alerted80Percent) {
      _alerted80Percent = true;
      final title = '📊 80% Monthly Data Limit Warning';
      final body = 'You have consumed 80% (${usedGb.toStringAsFixed(1)} GB of ${limitGb.toStringAsFixed(1)} GB) of your data quota.';

      await _dispatchNotification(
        userId: userId,
        title: title,
        body: body,
        category: NotificationCategory.dataUsage,
        showLocalAlert: () => NotificationService.showDataUsageNotification(
          percentage: 80.0,
          usedGb: usedGb,
          limitGb: limitGb,
        ),
      );
    }

    // 100% Limit Exceeded Alert
    if (usageRatio >= 1.0 && !_alerted100Percent) {
      _alerted100Percent = true;
      final title = '🚨 100% Data Limit Exceeded';
      final body = 'You have reached 100% (${limitGb.toStringAsFixed(1)} GB) of your configured monthly data limit. Roaming overage rates may apply.';

      await _dispatchNotification(
        userId: userId,
        title: title,
        body: body,
        category: NotificationCategory.dataUsage,
        showLocalAlert: () => NotificationService.showDataUsageNotification(
          percentage: 100.0,
          usedGb: usedGb,
          limitGb: limitGb,
        ),
      );
    }
  }

  /// 7. Security and account notifications
  Future<void> triggerSecurityNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    await _dispatchNotification(
      userId: userId,
      title: title,
      body: body,
      category: NotificationCategory.security,
      showLocalAlert: () => NotificationService.showSecurityNotification(
        title: title,
        body: body,
      ),
    );
  }

  // -------------------------------------------------------------
  // USER ACTIONS: READ / UNREAD / DELETE / PREFERENCES
  // -------------------------------------------------------------

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
      await StorageService.saveLocalNotifications(_notifications);
      await FirebaseService.updateNotificationReadStatus(id, true);
    }
  }

  Future<void> markAsUnread(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: false);
      notifyListeners();
      await StorageService.saveLocalNotifications(_notifications);
      await FirebaseService.updateNotificationReadStatus(id, false);
    }
  }

  Future<void> markAllAsRead(String userId) async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
    await StorageService.saveLocalNotifications(_notifications);

    // Update in Firestore
    for (final item in _notifications) {
      await FirebaseService.updateNotificationReadStatus(item.id, true);
    }
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    await StorageService.saveLocalNotifications(_notifications);
    await FirebaseService.deleteNotification(id);
  }

  Future<void> clearAll(String userId) async {
    _notifications.clear();
    notifyListeners();
    await StorageService.clearLocalNotifications();
    await FirebaseService.clearAllNotifications(userId);
  }

  Future<void> updatePreferences(NotificationPreferencesModel newPrefs) async {
    _preferences = newPrefs;
    notifyListeners();
    await StorageService.saveNotificationPreferences(newPrefs);
    await FirebaseService.saveNotificationPreferences(newPrefs);
  }

  Future<void> setDataLimitGb(double limitGb, String userId) async {
    _preferences = _preferences.copyWith(dataLimitGb: limitGb);
    _alerted80Percent = false;
    _alerted100Percent = false;
    notifyListeners();
    await StorageService.saveNotificationPreferences(_preferences);
    await FirebaseService.saveNotificationPreferences(_preferences);
  }

  Future<void> resetDataUsage(String userId) async {
    _preferences = _preferences.copyWith(currentDataUsedMb: 0.0);
    _alerted80Percent = false;
    _alerted100Percent = false;
    notifyListeners();
    await StorageService.saveNotificationPreferences(_preferences);
    await FirebaseService.saveNotificationPreferences(_preferences);
  }
}


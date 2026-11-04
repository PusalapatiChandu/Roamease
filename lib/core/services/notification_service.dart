import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  debugPrint('RoamEase FCM Background Message: ${message.messageId} - ${message.notification?.title}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String? _fcmToken;

  static String? get fcmToken => _fcmToken;

  static const String channelNetwork = 'roamease_network_channel';
  static const String channelRoaming = 'roamease_roaming_channel';
  static const String channelLocation = 'roamease_location_channel';
  static const String channelData = 'roamease_data_channel';
  static const String channelSecurity = 'roamease_security_channel';
  static const String channelGeneral = 'roamease_general_channel';

  /// Initializes both Flutter Local Notifications and Firebase Cloud Messaging
  static Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize Local Notifications Plugin
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('RoamEase Local Notification Tapped: ${response.payload}');
        },
      );

      // Create Android Notification Channels
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelNetwork,
              'Network & 5G Transitions',
              description: 'Alerts when mobile network switches between 4G and 5G bands',
              importance: Importance.high,
            ),
          );

          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelRoaming,
              'Roaming Status Alerts',
              description: 'Alerts when connected to partner roaming networks or home carriers',
              importance: Importance.high,
            ),
          );

          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelLocation,
              'Significant Location Updates',
              description: 'Alerts when subscriber crosses municipal or city boundaries',
              importance: Importance.defaultImportance,
            ),
          );

          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelData,
              'Data Usage Thresholds',
              description: 'Warnings when reaching 80% or 100% of configured monthly data limit',
              importance: Importance.high,
            ),
          );

          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelSecurity,
              'Account & SIM Security',
              description: 'Authentication alerts, login notices, and profile updates',
              importance: Importance.high,
            ),
          );

          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              channelGeneral,
              'General Notifications',
              description: 'System summaries and general telemetry alerts',
              importance: Importance.defaultImportance,
            ),
          );
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('RoamEase Local Notification init error: $e');
    }

    // 2. Setup Firebase Cloud Messaging
    await _initFirebaseMessaging();
  }

  static Future<void> _initFirebaseMessaging() async {
    try {
      // Background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Request FCM permissions
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('RoamEase FCM Permission Status: ${settings.authorizationStatus}');

      // Request Android 13 POST_NOTIFICATIONS permission
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }

      // Fetch FCM Registration Token
      _fcmToken = await messaging.getToken();
      debugPrint('RoamEase FCM Token: $_fcmToken');

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('RoamEase FCM Token refreshed: $newToken');
      });

      // Foreground message handler: display local heads-up notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('RoamEase FCM Foreground Message received: ${message.notification?.title}');
        final notification = message.notification;
        if (notification != null) {
          showGeneralNotification(
            title: notification.title ?? 'RoamEase Alert',
            body: notification.body ?? 'New notification received.',
          );
        }
      });

      // Handle message when app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('RoamEase FCM Message opened app: ${message.messageId}');
      });
    } catch (e) {
      debugPrint('RoamEase FCM initialization skipped or failed: $e');
    }
  }

  /// Request runtime Android notification permission
  static Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  // -------------------------------------------------------------
  // SPECIFIC EVENT NOTIFICATION EMITTERS
  // -------------------------------------------------------------

  /// 1. Network transition notification (4G <-> 5G)
  static Future<void> showNetworkTransitionNotification({
    required String oldType,
    required String newType,
    required String operator,
  }) async {
    final is5G = newType.toUpperCase().contains('5G') || newType.toUpperCase().contains('NR');
    final title = is5G ? '⚡ 5G Network Connected' : '📶 Switched to 4G LTE';
    final body = is5G
        ? 'Your terminal connected to $newType on $operator. High-speed broadband active.'
        : 'Network changed from $oldType to $newType on $operator.';

    await _show(
      id: 201,
      channelId: channelNetwork,
      channelName: 'Network & 5G Transitions',
      title: title,
      body: body,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// 2. Connection loss & restoration alert
  static Future<void> showConnectionStatusNotification({
    required bool isConnected,
    required String operator,
    required String type,
  }) async {
    final title = isConnected ? '✅ Cellular Connection Restored' : '⚠️ Cellular Connection Lost';
    final body = isConnected
        ? 'Reconnected to $operator ($type). Mobile data and roaming services resumed.'
        : 'Lost connection to mobile network. Searching for available carrier cells.';

    await _show(
      id: 202,
      channelId: channelNetwork,
      channelName: 'Network & 5G Transitions',
      title: title,
      body: body,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// 3. Poor signal alert
  static Future<void> showPoorSignalAlert({
    required int dbm,
    required String operatorName,
  }) async {
    await _show(
      id: 203,
      channelId: channelNetwork,
      channelName: 'Network & 5G Transitions',
      title: '⚠️ Weak Signal Alert ($dbm dBm)',
      body: 'Cellular reception dropped to $dbm dBm on $operatorName. Voice and roaming data quality may degrade.',
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// 4. Roaming status alert
  static Future<void> showRoamingAlert({
    required String operatorName,
    required bool isRoaming,
    String? countryIso,
  }) async {
    final title = isRoaming ? '🌐 Roaming Network Active' : '🏠 Home Carrier Connected';
    final body = isRoaming
        ? 'Connected to partner carrier $operatorName${countryIso != null ? " ($countryIso)" : ""}. Roaming rates apply.'
        : 'Switched back to your primary home network ($operatorName). Standard tariff active.';

    await _show(
      id: 204,
      channelId: channelRoaming,
      channelName: 'Roaming Status Alerts',
      title: title,
      body: body,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// 5. Significant location change notification (with consent)
  static Future<void> showSignificantLocationNotification({
    required String city,
    required String area,
  }) async {
    await _show(
      id: 205,
      channelId: channelLocation,
      channelName: 'Significant Location Updates',
      title: '📍 Location Boundary Changed',
      body: 'Entered $city, $area. Local roaming telemetry and nearby mobile towers updated.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
  }

  /// 6. Data usage threshold warnings (80% and 100%)
  static Future<void> showDataUsageNotification({
    required double percentage,
    required double usedGb,
    required double limitGb,
  }) async {
    final is100 = percentage >= 100.0;
    final title = is100 ? '🚨 100% Data Limit Reached' : '📊 80% Data Limit Warning';
    final body = is100
        ? 'You have consumed 100% (${limitGb.toStringAsFixed(1)} GB) of your configured data allowance. Speeds may be throttled.'
        : 'You have reached 80% (${usedGb.toStringAsFixed(1)} GB / ${limitGb.toStringAsFixed(1)} GB) of your monthly data quota.';

    await _show(
      id: 206,
      channelId: channelData,
      channelName: 'Data Usage Thresholds',
      title: title,
      body: body,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// 7. Security and account notifications
  static Future<void> showSecurityNotification({
    required String title,
    required String body,
  }) async {
    await _show(
      id: 207,
      channelId: channelSecurity,
      channelName: 'Account & SIM Security',
      title: title,
      body: body,
      importance: Importance.high,
      priority: Priority.high,
    );
  }

  /// 8. General notification
  static Future<void> showGeneralNotification({
    required String title,
    required String body,
  }) async {
    await _show(
      id: 208,
      channelId: channelGeneral,
      channelName: 'General Notifications',
      title: title,
      body: body,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
  }

  /// Ongoing status for active GPS waypoint tracking
  static Future<void> showTrackingStatusNotification({
    required bool isTracking,
    required String locationSummary,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelLocation,
      'Location Tracking',
      channelDescription: 'Ongoing status of subscriber location tracking',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    try {
      if (isTracking) {
        await _notificationsPlugin.show(
          id: 103,
          title: '📍 RoamEase Location Tracking Active',
          body: 'Monitoring location updates: $locationSummary',
          notificationDetails: details,
        );
      } else {
        await _notificationsPlugin.cancel(id: 103);
      }
    } catch (_) {}
  }

  // Internal helper to dispatch local notifications
  static Future<void> _show({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required Importance importance,
    required Priority priority,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('RoamEase failed to show notification: $e');
    }
  }
}

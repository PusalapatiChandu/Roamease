import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../constants/app_constants.dart';
import '../../models/subscriber_model.dart';
import '../../models/location_record_model.dart';
import '../../models/speed_test_result_model.dart';
import '../../models/notification_model.dart';
import '../../models/notification_preferences_model.dart';

class FirebaseService {
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static FirebaseAuth? get auth => _isInitialized ? FirebaseAuth.instance : null;
  static FirebaseFirestore? get firestore => _isInitialized ? FirebaseFirestore.instance : null;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
    } catch (e) {
      // Firebase might not be configured with real credentials yet
      _isInitialized = false;
    }
  }

  // --- SUBSCRIBER REPOSITORY ---
  static Future<void> saveSubscriber(SubscriberModel subscriber) async {
    if (!_isInitialized || firestore == null) return;
    try {
      await firestore!
          .collection(AppConstants.colSubscribers)
          .doc(subscriber.uid)
          .set(subscriber.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<SubscriberModel?> getSubscriber(String uid) async {
    if (!_isInitialized || firestore == null) return null;
    try {
      final doc = await firestore!
          .collection(AppConstants.colSubscribers)
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        return SubscriberModel.fromMap(doc.data()!, docId: doc.id);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> deleteSubscriber(String uid) async {
    if (!_isInitialized || firestore == null) return;
    try {
      await firestore!.collection(AppConstants.colSubscribers).doc(uid).delete();
    } catch (_) {}
  }

  // --- LOCATION HISTORY REPOSITORY ---
  static Future<void> saveLocationRecord(LocationRecordModel record) async {
    if (!_isInitialized || firestore == null) return;
    try {
      await firestore!
          .collection(AppConstants.colLocationHistory)
          .doc(record.id)
          .set(record.toMap());
    } catch (_) {}
  }

  static Future<List<LocationRecordModel>> fetchLocationHistory(String userId) async {
    if (!_isInitialized || firestore == null) return [];
    try {
      final snapshot = await firestore!
          .collection(AppConstants.colLocationHistory)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => LocationRecordModel.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> deleteLocationRecord(String recordId) async {
    if (!_isInitialized || firestore == null) return;
    try {
      await firestore!.collection(AppConstants.colLocationHistory).doc(recordId).delete();
    } catch (_) {}
  }

  // --- NETWORK HISTORY REPOSITORY ---
  static Future<void> saveSpeedTestResult(SpeedTestResultModel result, String userId) async {
    if (!_isInitialized || firestore == null) return;
    try {
      final map = result.toMap()..['userId'] = userId;
      await firestore!
          .collection(AppConstants.colNetworkHistory)
          .doc(result.id)
          .set(map);
    } catch (_) {}
  }

  static Future<List<SpeedTestResultModel>> fetchNetworkHistory(String userId) async {
    if (!_isInitialized || firestore == null) return [];
    try {
      final snapshot = await firestore!
          .collection(AppConstants.colNetworkHistory)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      return snapshot.docs
          .map((doc) => SpeedTestResultModel.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- FCM PUSH TOKEN ---
  static Future<void> saveFcmToken(String userId, String token) async {
    if (!_isInitialized || firestore == null) return;
    try {
      await firestore!
          .collection(AppConstants.colSubscribers)
          .doc(userId)
          .set({'fcmToken': token, 'lastTokenUpdate': DateTime.now().toIso8601String()}, SetOptions(merge: true));
    } catch (_) {}
  }

  // --- NOTIFICATIONS REPOSITORY ---
  static Future<void> saveNotification(NotificationModel notification) async {
    if (!_isInitialized || firestore == null) return;
    try {
      await firestore!
          .collection(AppConstants.colNotifications)
          .doc(notification.id)
          .set(notification.toMap());
    } catch (_) {}
  }

  static Future<List<NotificationModel>> fetchNotifications(String userId) async {
    if (!_isInitialized || firestore == null) return [];
    try {
      final snapshot = await firestore!
          .collection(AppConstants.colNotifications)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> updateNotificationReadStatus(String notificationId, bool isRead) async {
    if (!_isInitialized || firestore == null) return;
    try {
      await firestore!
          .collection(AppConstants.colNotifications)
          .doc(notificationId)
          .update({'isRead': isRead});
    } catch (_) {}
  }

  static Future<void> deleteNotification(String notificationId) async {
    if (!_isInitialized || firestore == null) return;
    try {
      await firestore!.collection(AppConstants.colNotifications).doc(notificationId).delete();
    } catch (_) {}
  }

  static Future<void> clearAllNotifications(String userId) async {
    if (!_isInitialized || firestore == null) return;
    try {
      final snapshot = await firestore!
          .collection(AppConstants.colNotifications)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = firestore!.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  // --- USER SETTINGS & NOTIFICATION PREFERENCES REPOSITORY ---
  static Future<void> saveNotificationPreferences(NotificationPreferencesModel prefs) async {
    if (!_isInitialized || firestore == null) return;
    try {
      await firestore!
          .collection(AppConstants.colUserSettings)
          .doc(prefs.userId)
          .set({'notificationPreferences': prefs.toMap()}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<NotificationPreferencesModel?> fetchNotificationPreferences(String userId) async {
    if (!_isInitialized || firestore == null) return null;
    try {
      final doc = await firestore!.collection(AppConstants.colUserSettings).doc(userId).get();
      if (doc.exists && doc.data() != null && doc.data()!['notificationPreferences'] != null) {
        final map = doc.data()!['notificationPreferences'] as Map<String, dynamic>;
        return NotificationPreferencesModel.fromMap(map, userId: userId);
      }
    } catch (_) {}
    return null;
  }
}

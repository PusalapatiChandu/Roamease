import 'package:flutter_test/flutter_test.dart';
import 'package:roamease/models/network_info_model.dart';
import 'package:roamease/models/subscriber_model.dart';
import 'package:roamease/models/speed_test_result_model.dart';
import 'package:roamease/models/notification_model.dart';
import 'package:roamease/models/notification_preferences_model.dart';
import 'package:roamease/core/utils/formatters.dart';

void main() {
  group('RoamEase Model & Telemetry Tests', () {
    test('SubscriberModel serialize and deserialize', () {
      final sub = SubscriberModel(
        uid: 'sub_123',
        fullName: 'Alexander Wright',
        email: 'alex@roamease.io',
        phone: '+1 555 1234',
        operatorName: 'Reliance Jio',
        simType: '5G',
        deviceModel: 'Samsung Galaxy S24',
        locationConsent: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final map = sub.toMap();
      final restored = SubscriberModel.fromMap(map, docId: 'sub_123');

      expect(restored.fullName, 'Alexander Wright');
      expect(restored.operatorName, 'Reliance Jio');
      expect(restored.simType, '5G');
      expect(restored.locationConsent, isTrue);
    });

    test('NetworkInfoModel quality labels and 5G detection', () {
      final network = NetworkInfoModel(
        networkType: '5G NR',
        operatorName: 'Bharti Airtel',
        signalStrengthDbm: -78,
        signalLevel: 4,
        signalAsu: 25,
        isRoaming: false,
        isWifi: false,
        isCellular: true,
        isConnected: true,
        is5gSupported: true,
        simState: 'Ready',
        timestamp: DateTime.now(),
      );

      expect(network.is5gActive, isTrue);
      expect(network.qualityLabel, 'Excellent');
      expect(network.isPoorConnection, isFalse);
    });

    test('SpeedTestResultModel serialization and metrics validation', () {
      final result = SpeedTestResultModel(
        id: 'speed_test_1',
        downloadSpeedMbps: 148.65,
        uploadSpeedMbps: 45.20,
        pingMs: 18,
        jitterMs: 3,
        networkType: '5G NR',
        operatorName: 'Reliance Jio',
        timestamp: DateTime.now(),
      );

      final map = result.toMap();
      final restored = SpeedTestResultModel.fromMap(map);

      expect(restored.downloadSpeedMbps, 148.65);
      expect(restored.uploadSpeedMbps, 45.20);
      expect(restored.pingMs, 18);
      expect(restored.jitterMs, 3);
      expect(restored.networkType, '5G NR');
    });

    test('Travel speed conversion from m/s to km/h', () {
      // 10 m/s = 36 km/h
      const double mps = 10.0;
      final double kmh = mps * 3.6;
      expect(kmh, 36.0);

      // Walking speed: 1.4 m/s ~ 5.04 km/h
      const double walkingMps = 1.4;
      final double walkingKmh = double.parse((walkingMps * 3.6).toStringAsFixed(1));
      expect(walkingKmh, 5.0);
    });

    test('NotificationModel serialization and category parsing', () {
      final notif = NotificationModel(
        id: 'notif_1',
        userId: 'user_123',
        title: '⚡ 5G Network Connected',
        body: 'Switched to 5G Ultra-Wideband on Reliance Jio.',
        category: NotificationCategory.network,
        timestamp: DateTime(2026, 1, 1, 12, 0),
        isRead: false,
      );

      final map = notif.toMap();
      final restored = NotificationModel.fromMap(map, docId: 'notif_1');

      expect(restored.id, 'notif_1');
      expect(restored.title, '⚡ 5G Network Connected');
      expect(restored.category, NotificationCategory.network);
      expect(restored.isRead, isFalse);

      final readCopy = restored.copyWith(isRead: true);
      expect(readCopy.isRead, isTrue);
    });

    test('NotificationPreferencesModel quota calculation and defaults', () {
      final prefs = NotificationPreferencesModel.defaultPreferences('user_123');
      expect(prefs.allNotificationsEnabled, isTrue);
      expect(prefs.networkChanges, isTrue);
      expect(prefs.dataLimitGb, 10.0);

      final map = prefs.toMap();
      final restored = NotificationPreferencesModel.fromMap(map);
      expect(restored.dataLimitGb, 10.0);

      final updated = restored.copyWith(dataLimitGb: 20.0, currentDataUsedMb: 16384.0);
      expect(updated.dataLimitGb, 20.0);
      expect(updated.currentDataUsedMb / 1024.0, 16.0); // 16 GB used out of 20 GB (80% threshold reached)
    });

    test('Formatters utility check', () {
      expect(Formatters.formatDbm(-85), '-85 dBm');
      expect(Formatters.formatDbm(-1), 'N/A');
      expect(Formatters.formatSpeed(150.45), '150.45 Mbps');
      expect(Formatters.formatCoordinates(37.7749, -122.4194), '37.7749° N, 122.4194° W');
    });
  });
}

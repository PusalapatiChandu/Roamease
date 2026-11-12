import 'package:flutter_test/flutter_test.dart';
import 'package:roamease/models/network_info_model.dart';
import 'package:roamease/models/cell_tower_model.dart';
import 'package:roamease/models/mapped_base_station_model.dart';
import 'package:roamease/models/subscriber_model.dart';
import 'package:roamease/models/speed_test_result_model.dart';
import 'package:roamease/models/notification_model.dart';
import 'package:roamease/models/notification_preferences_model.dart';
import 'package:roamease/core/utils/formatters.dart';
import 'package:roamease/core/utils/telecom_utils.dart';

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

    test('TelecomUtils signal quality tier classification and operator resolution', () {
      expect(TelecomUtils.classifySignalQuality(rsrp: -82, dbm: -82), 'Strong');
      expect(TelecomUtils.classifySignalQuality(rsrp: -97, dbm: -97), 'Moderate');
      expect(TelecomUtils.classifySignalQuality(rsrp: -114, dbm: -114), 'Weak');
      expect(TelecomUtils.classifySignalQuality(rsrp: null, dbm: -1, level: 0), 'Unavailable');
      expect(TelecomUtils.classifySignalQuality(rsrp: -80, isConnected: false), 'Unavailable');

      expect(TelecomUtils.resolveOperatorFromMccMnc('405', '869'), 'Reliance Jio');
      expect(TelecomUtils.resolveOperatorFromMccMnc('404', '40'), 'Bharti Airtel');
      expect(TelecomUtils.resolveOperatorFromMccMnc('999', '99'), isNull);

      expect(TelecomUtils.resolveBandFromArfcn(633333, '5G NR'), '5G NR n78 (3500 MHz C-Band)');
      expect(TelecomUtils.resolveBandFromArfcn(1300, '4G LTE'), 'LTE Band 3 (1800 MHz)');

      expect(TelecomUtils.formatDistance(420), '420 m');
      expect(TelecomUtils.formatDistance(1450), '1.45 km');
    });

    test('CellTowerModel parses Serving vs Neighbouring RSRP, RSRQ, SINR telemetry', () {
      final serving = CellTowerModel.fromMap({
        'cellId': '987654321',
        'type': '5G NR',
        'dbm': -86,
        'level': 4,
        'tac': 4012,
        'pci': 215,
        'mcc': '405',
        'mnc': '869',
        'arfcn': 633333,
        'rsrp': -86,
        'rsrq': -10,
        'sinr': 19,
        'isRegistered': true,
      });

      expect(serving.cellRoleLabel, 'SERVING CELL');
      expect(serving.resolvedOperatorName, 'Reliance Jio');
      expect(serving.signalQualityTier, 'Strong');
      expect(serving.rsrp, -86);
      expect(serving.rsrq, -10);
      expect(serving.sinr, 19);
      expect(serving.hasMappedCoordinates, isFalse);
    });

    test('MappedBaseStationModel separates measured RF from estimated coverage', () {
      final unassociatedOsmMast = MappedBaseStationModel(
        id: 'osm_12345',
        latitude: 13.0320,
        longitude: 80.0200,
        operatorName: 'Bharti Airtel',
        generation: '4G LTE',
        source: 'OpenStreetMap Telecom Registry',
        distanceMeters: 310.0,
        estimatedCoverageRadiusMeters: 1500.0,
        coverageDatasetLabel: '3GPP Macro Reference Footprint (Estimated)',
      );

      expect(unassociatedOsmMast.hasMeasuredSignal, isFalse);
      expect(unassociatedOsmMast.measuredSignalTier, 'Unavailable');
      expect(unassociatedOsmMast.formattedDistance, '310 m');
      expect(unassociatedOsmMast.estimatedCoverageTier, 'Strong (Est.)');

      final matchedServingTower = unassociatedOsmMast.copyWith(
        isServingCell: true,
        measuredDbm: -96,
        measuredRsrp: -96,
        measuredRsrq: -11,
        measuredSinr: 12,
      );

      expect(matchedServingTower.hasMeasuredSignal, isTrue);
      expect(matchedServingTower.measuredSignalTier, 'Moderate');
    });
  });
}

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/network_info_model.dart';
import '../../models/cell_tower_model.dart';
import '../../models/mapped_base_station_model.dart';
import '../../models/speed_test_result_model.dart';
import '../core/services/base_station_service.dart';
import '../core/services/telephony_service.dart';
import '../core/services/speed_test_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/firebase_service.dart';
import 'notification_provider.dart';

class NetworkProvider extends ChangeNotifier {
  final TelephonyService _telephonyService = TelephonyService();
  final SpeedTestService _speedTestService = SpeedTestService();
  final BaseStationService _baseStationService = BaseStationService();

  NotificationProvider? _notificationProvider;
  String _userId = 'guest';

  NetworkInfoModel _currentNetwork = NetworkInfoModel.initial();
  List<CellTowerModel> _cellTowers = [];
  List<MappedBaseStationModel> _allFetchedBaseStations = [];
  List<String> _towerSourcesUsed = [];
  List<String> _towerUnavailableNotes = [];
  DateTime? _lastTowerScanTime;
  double? _lastTowerScanLat;
  double? _lastTowerScanLng;
  double _lastScannedRadiusMeters = 5000.0;
  double? _lastSignalMoveLat;
  double? _lastSignalMoveLng;
  double _towerSearchRadiusMeters = 5000.0;
  String _openCellIdApiKey = '';
  bool _hasValidGoogleMapsKey = false;

  List<SpeedTestResultModel> _speedHistory = [];

  bool _isRefreshing = false;
  bool _isScanningTowers = false;
  bool _isRunningSpeedTest = false;
  SpeedTestProgress? _speedTestProgress;
  SpeedTestResultModel? _latestSpeedTest;

  Timer? _pollingTimer;
  bool _alertedForPoorSignal = false;

  NetworkInfoModel get currentNetwork => _currentNetwork;
  List<CellTowerModel> get cellTowers => _cellTowers;
  List<MappedBaseStationModel> get mappedBaseStations => _allFetchedBaseStations
      .where((s) => s.isServingCell || s.distanceMeters <= _towerSearchRadiusMeters)
      .toList();
  List<String> get towerSourcesUsed => _towerSourcesUsed;
  List<String> get towerUnavailableNotes => _towerUnavailableNotes;
  DateTime? get lastTowerScanTime => _lastTowerScanTime;
  double get towerSearchRadiusMeters => _towerSearchRadiusMeters;
  String get openCellIdApiKey => _openCellIdApiKey;
  bool get hasValidGoogleMapsKey => _hasValidGoogleMapsKey;

  List<SpeedTestResultModel> get speedHistory => _speedHistory;
  bool get isRefreshing => _isRefreshing;
  bool get isScanningTowers => _isScanningTowers;
  bool get isRunningSpeedTest => _isRunningSpeedTest;
  SpeedTestProgress? get speedTestProgress => _speedTestProgress;
  SpeedTestResultModel? get latestSpeedTest => _latestSpeedTest;

  CellTowerModel? get servingCell {
    for (final c in _cellTowers) {
      if (c.isRegistered) return c;
    }
    return null;
  }

  List<CellTowerModel> get neighbouringCells =>
      _cellTowers.where((c) => !c.isRegistered).toList();

  MappedBaseStationModel? get servingMappedStation {
    for (final s in mappedBaseStations) {
      if (s.isServingCell) return s;
    }
    return null;
  }

  MappedBaseStationModel? get nearestMappedStation =>
      mappedBaseStations.isNotEmpty ? mappedBaseStations.first : null;

  NetworkProvider() {
    _init();
  }

  void _init() {
    _speedHistory = StorageService.getLocalSpeedTests();
    if (_speedHistory.isNotEmpty) {
      _latestSpeedTest = _speedHistory.first;
    }
    _openCellIdApiKey = StorageService.openCellIdApiKey;
    _telephonyService.hasValidGoogleMapsKey().then((val) {
      _hasValidGoogleMapsKey = val;
      notifyListeners();
    });

    refreshNetworkDetails();

    // Periodic telemetry update every 12 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      refreshNetworkDetails(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void attachNotificationProvider(NotificationProvider notifProvider, String userId) {
    _notificationProvider = notifProvider;
    _userId = userId;
  }

  Future<void> setOpenCellIdApiKey(String key) async {
    _openCellIdApiKey = key.trim();
    await StorageService.setOpenCellIdApiKey(_openCellIdApiKey);
    notifyListeners();
    if (_lastTowerScanLat != null && _lastTowerScanLng != null) {
      await scanNearbyBaseStations(_lastTowerScanLat!, _lastTowerScanLng!, force: true);
    }
  }

  Future<void> setTowerSearchRadius(double meters) async {
    _towerSearchRadiusMeters = meters.clamp(1500.0, 10000.0);
    notifyListeners();
    if (_lastTowerScanLat != null &&
        _lastTowerScanLng != null &&
        (_allFetchedBaseStations.isEmpty || _towerSearchRadiusMeters > _lastScannedRadiusMeters)) {
      await scanNearbyBaseStations(_lastTowerScanLat!, _lastTowerScanLng!, force: true);
    }
  }

  Future<void> refreshNetworkDetails({bool silent = false}) async {
    if (!silent) {
      _isRefreshing = true;
      notifyListeners();
    }

    try {
      final info = await _telephonyService.fetchNetworkDetails();
      _currentNetwork = info;

      // Detected serving & neighbouring cells
      final freshCells = await _telephonyService.fetchNearbyCellTowers();
      // Preserve previously resolved coordinates if same cellId already looked up
      if (_cellTowers.isNotEmpty) {
        final prevById = {
          for (final c in _cellTowers)
            if (c.hasMappedCoordinates) '${c.type}_${c.mcc}_${c.mnc}_${c.cellId}': c
        };
        _cellTowers = freshCells.map((cell) {
          final match = prevById['${cell.type}_${cell.mcc}_${cell.mnc}_${cell.cellId}'];
          if (match != null) {
            final double? updatedDist = (_lastSignalMoveLat != null && _lastSignalMoveLng != null)
                ? Geolocator.distanceBetween(
                    _lastSignalMoveLat!,
                    _lastSignalMoveLng!,
                    match.mappedLat!,
                    match.mappedLng!,
                  )
                : match.distanceMeters;
            return cell.copyWith(
              mappedLat: match.mappedLat,
              mappedLng: match.mappedLng,
              estimatedRangeMeters: match.estimatedRangeMeters,
              distanceMeters: updatedDist,
              coordinateSource: match.coordinateSource,
            );
          }
          return cell;
        }).toList();
      } else {
        _cellTowers = freshCells;
      }

      // Sync serving cell RF measurements onto already-mapped stations
      if (_allFetchedBaseStations.isNotEmpty) {
        _allFetchedBaseStations = _allFetchedBaseStations.map((station) {
          CellTowerModel? match;
          for (final cell in _cellTowers) {
            if (station.cellId != null && station.cellId == cell.cellId) {
              match = cell;
              break;
            }
          }
          if (match != null) {
            return station.copyWith(
              isServingCell: match.isRegistered,
              isNeighbourCell: !match.isRegistered,
              measuredDbm: match.dbm != -1 ? match.dbm : null,
              measuredRsrp: match.rsrp,
              measuredRsrq: match.rsrq,
              measuredSinr: match.sinr,
              timingAdvance: match.timingAdvance,
            );
          }
          return station.copyWith(isServingCell: false, isNeighbourCell: false);
        }).toList();
      }

      // Trigger event notifications via NotificationProvider
      if (_notificationProvider != null) {
        _notificationProvider!.onNetworkTypeChanged(
          userId: _userId,
          currentType: info.networkType,
          operatorName: info.operatorName,
        );

        _notificationProvider!.onConnectionStateChanged(
          userId: _userId,
          isConnected: info.isConnected,
          operatorName: info.operatorName,
          networkType: info.networkType,
        );

        if (info.isPoorConnection && info.signalStrengthDbm != -1) {
          if (!_alertedForPoorSignal) {
            _alertedForPoorSignal = true;
            _notificationProvider!.onPoorSignalDetected(
              userId: _userId,
              dbm: info.signalStrengthDbm,
              operatorName: info.operatorName,
            );
          }
        } else {
          _alertedForPoorSignal = false;
        }

        _notificationProvider!.onRoamingStatusChanged(
          userId: _userId,
          isRoaming: info.isRoaming,
          operatorName: info.operatorName,
          countryIso: 'Global Partner',
        );
      }
    } catch (_) {}

    _isRefreshing = false;
    notifyListeners();
  }

  /// Called by LocationProvider whenever subscriber's GPS position updates during movement.
  Future<void> onSubscriberLocationUpdated(double lat, double lng) async {
    // 1. Immediately recalculate live distances to mapped base stations & mapped detected cells
    if (_allFetchedBaseStations.isNotEmpty) {
      _allFetchedBaseStations = _baseStationService.recalculateDistances(
        subscriberLat: lat,
        subscriberLng: lng,
        stations: _allFetchedBaseStations,
      );
    }

    if (_cellTowers.isNotEmpty) {
      _cellTowers = _cellTowers.map((c) {
        if (c.hasMappedCoordinates) {
          final dist = Geolocator.distanceBetween(lat, lng, c.mappedLat!, c.mappedLng!);
          return c.copyWith(distanceMeters: dist);
        }
        return c;
      }).toList();
    }

    notifyListeners();

    // 2. Refresh Telephony RF signal & serving/neighbouring cells if moved >= 25 meters
    final double movedSinceSignal = (_lastSignalMoveLat != null && _lastSignalMoveLng != null)
        ? Geolocator.distanceBetween(_lastSignalMoveLat!, _lastSignalMoveLng!, lat, lng)
        : 99999.0;

    if (movedSinceSignal >= 25.0) {
      _lastSignalMoveLat = lat;
      _lastSignalMoveLng = lng;
      await refreshNetworkDetails(silent: true);
    }

    // 3. Re-query external base station datasets if first GPS lock or moved >= 400 meters
    final double movedSinceTowerScan = (_lastTowerScanLat != null && _lastTowerScanLng != null)
        ? Geolocator.distanceBetween(_lastTowerScanLat!, _lastTowerScanLng!, lat, lng)
        : 99999.0;

    if (_lastTowerScanLat == null || movedSinceTowerScan >= 400.0) {
      await scanNearbyBaseStations(lat, lng);
    }
  }

  /// Queries real external base station datasets for nearby 4G/5G towers & cell coordinates.
  Future<void> scanNearbyBaseStations(
    double latitude,
    double longitude, {
    bool force = false,
  }) async {
    if (_isScanningTowers) return;

    if (!force && _lastTowerScanTime != null && _lastTowerScanLat != null && _lastTowerScanLng != null) {
      final elapsed = DateTime.now().difference(_lastTowerScanTime!).inSeconds;
      final dist = Geolocator.distanceBetween(_lastTowerScanLat!, _lastTowerScanLng!, latitude, longitude);
      if (elapsed < 20 && dist < 300) {
        return;
      }
    }

    _isScanningTowers = true;
    notifyListeners();

    try {
      // Ensure latest modem cell scan is included
      await refreshNetworkDetails(silent: true);

      final double fetchRadius = math.max(_towerSearchRadiusMeters, 5000.0);
      final result = await _baseStationService.fetchNearbyBaseStations(
        latitude: latitude,
        longitude: longitude,
        detectedCells: _cellTowers,
        openCellIdApiKey: _openCellIdApiKey,
        searchRadiusMeters: fetchRadius,
      );

      _allFetchedBaseStations = result.mappedStations;
      _cellTowers = result.enrichedDetectedCells;
      _towerSourcesUsed = result.sourcesUsed;
      _towerUnavailableNotes = result.unavailableNotes;
      _lastTowerScanTime = result.fetchedAt;
      _lastTowerScanLat = latitude;
      _lastTowerScanLng = longitude;
      _lastScannedRadiusMeters = fetchRadius;
    } catch (_) {
      _towerUnavailableNotes = ['Unable to query base station datasets cleanly. Check internet access.'];
    }

    _isScanningTowers = false;
    notifyListeners();
  }

  Future<SpeedTestResultModel?> runSpeedTest({required String userId}) async {
    if (_isRunningSpeedTest) return null;

    _isRunningSpeedTest = true;
    _speedTestProgress = null;
    notifyListeners();

    try {
      final result = await _speedTestService.runSpeedTest(
        networkType: _currentNetwork.networkType,
        operatorName: _currentNetwork.operatorName,
        onProgress: (progress) {
          _speedTestProgress = progress;
          notifyListeners();
        },
      );

      _latestSpeedTest = result;
      _speedHistory.insert(0, result);

      await StorageService.saveLocalSpeedTest(result);
      await FirebaseService.saveSpeedTestResult(result, userId);

      await _notificationProvider?.recordDataUsage(
        userId: userId,
        additionalMb: 12.5,
      );

      _isRunningSpeedTest = false;
      notifyListeners();
      return result;
    } catch (_) {
      _isRunningSpeedTest = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadCloudNetworkHistory(String userId) async {
    if (!FirebaseService.isInitialized) return;
    try {
      final cloudList = await FirebaseService.fetchNetworkHistory(userId);
      if (cloudList.isNotEmpty) {
        _speedHistory = cloudList;
        _latestSpeedTest = cloudList.first;
        notifyListeners();
      }
    } catch (_) {}
  }
}

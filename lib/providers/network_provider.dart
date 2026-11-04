import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/network_info_model.dart';
import '../../models/cell_tower_model.dart';
import '../../models/speed_test_result_model.dart';
import '../core/services/telephony_service.dart';
import '../core/services/speed_test_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/firebase_service.dart';
import 'notification_provider.dart';

class NetworkProvider extends ChangeNotifier {
  final TelephonyService _telephonyService = TelephonyService();
  final SpeedTestService _speedTestService = SpeedTestService();

  NotificationProvider? _notificationProvider;
  String _userId = 'guest';

  NetworkInfoModel _currentNetwork = NetworkInfoModel.initial();
  List<CellTowerModel> _cellTowers = [];
  List<SpeedTestResultModel> _speedHistory = [];

  bool _isRefreshing = false;
  bool _isRunningSpeedTest = false;
  SpeedTestProgress? _speedTestProgress;
  SpeedTestResultModel? _latestSpeedTest;

  Timer? _pollingTimer;
  bool _alertedForPoorSignal = false;

  NetworkInfoModel get currentNetwork => _currentNetwork;
  List<CellTowerModel> get cellTowers => _cellTowers;
  List<SpeedTestResultModel> get speedHistory => _speedHistory;
  bool get isRefreshing => _isRefreshing;
  bool get isRunningSpeedTest => _isRunningSpeedTest;
  SpeedTestProgress? get speedTestProgress => _speedTestProgress;
  SpeedTestResultModel? get latestSpeedTest => _latestSpeedTest;

  NetworkProvider() {
    _init();
  }

  void _init() {
    // Load local speed test history
    _speedHistory = StorageService.getLocalSpeedTests();
    if (_speedHistory.isNotEmpty) {
      _latestSpeedTest = _speedHistory.first;
    }

    refreshNetworkDetails();

    // Periodic telemetry update every 15 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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

  Future<void> refreshNetworkDetails({bool silent = false}) async {
    if (!silent) {
      _isRefreshing = true;
      notifyListeners();
    }

    try {
      final info = await _telephonyService.fetchNetworkDetails();
      _currentNetwork = info;

      // Cell towers
      _cellTowers = await _telephonyService.fetchNearbyCellTowers();

      // Trigger event notifications via NotificationProvider
      if (_notificationProvider != null) {
        // 1. 4G <-> 5G network transition alert
        _notificationProvider!.onNetworkTypeChanged(
          userId: _userId,
          currentType: info.networkType,
          operatorName: info.operatorName,
        );

        // 2. Cellular connection state alert (lost/restored)
        _notificationProvider!.onConnectionStateChanged(
          userId: _userId,
          isConnected: info.isConnected,
          operatorName: info.operatorName,
          networkType: info.networkType,
        );

        // 3. Poor signal alert (< -110 dBm)
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

        // 4. Roaming network alert
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

      // Save locally
      await StorageService.saveLocalSpeedTest(result);

      // Save to Firebase Firestore
      await FirebaseService.saveSpeedTestResult(result, userId);

      // Record test payload (~12.5 MB) towards monthly data quota
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

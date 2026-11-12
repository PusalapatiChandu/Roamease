import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../models/location_record_model.dart';
import '../core/services/location_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/firebase_service.dart';
import '../core/services/notification_service.dart';
import 'network_provider.dart';
import 'notification_provider.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();

  NotificationProvider? _notificationProvider;
  NetworkProvider? _networkProvider;
  String _userId = 'guest';
  bool _userConsent = true;

  Position? _currentPosition;
  LocationAddressResult? _currentAddress;
  bool _isLoading = false;
  bool _isTrackingActive = false;
  bool _hasPermission = false;
  bool _isPermissionPermanentlyDenied = false;
  bool _isLocationServiceEnabled = true;
  String? _errorMessage;

  // Travel speed telemetry
  double _currentTravelSpeedKmh = 0.0;
  String _speedStatusLabel = 'Stationary';
  Position? _previousPosition;
  DateTime? _previousPositionTime;

  List<LocationRecordModel> _locationHistory = [];
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Position>? _foregroundMoveSubscription;

  // Getters
  Position? get currentPosition => _currentPosition;
  LocationAddressResult? get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  bool get isTrackingActive => _isTrackingActive;
  bool get hasPermission => _hasPermission;
  bool get isPermissionPermanentlyDenied => _isPermissionPermanentlyDenied;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;
  String? get errorMessage => _errorMessage;
  double get currentTravelSpeedKmh => _currentTravelSpeedKmh;
  String get speedStatusLabel => _speedStatusLabel;
  List<LocationRecordModel> get locationHistory => _locationHistory;

  void attachNotificationProvider(
    NotificationProvider notifProvider,
    String userId,
    bool userConsent, {
    NetworkProvider? networkProvider,
  }) {
    _notificationProvider = notifProvider;
    _userId = userId;
    _userConsent = userConsent;
    if (networkProvider != null) {
      final isFirstAttach = _networkProvider == null;
      _networkProvider = networkProvider;
      if (isFirstAttach && _currentPosition != null) {
        _networkProvider!.onSubscriberLocationUpdated(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
    }
  }

  LocationProvider() {
    _init();
  }

  void _init() {
    _locationHistory = StorageService.getLocalLocationHistory();
    _isTrackingActive = StorageService.isTrackingActive;
    checkAndFetchLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _foregroundMoveSubscription?.cancel();
    super.dispose();
  }

  /// Calculates accurate travel speed combining hardware Doppler velocity and GPS delta distance
  void _updateTravelSpeed(Position newPos) {
    final now = DateTime.now();

    if (newPos.speed > 0.2) {
      final rawKmh = newPos.speed * 3.6;
      _currentTravelSpeedKmh = double.parse(rawKmh.toStringAsFixed(1));
    } else if (_previousPosition != null && _previousPositionTime != null) {
      final elapsedSec = now.difference(_previousPositionTime!).inMilliseconds / 1000.0;
      if (elapsedSec >= 0.8) {
        final distanceMeters = Geolocator.distanceBetween(
          _previousPosition!.latitude,
          _previousPosition!.longitude,
          newPos.latitude,
          newPos.longitude,
        );

        if (distanceMeters >= 1.5) {
          final computedMps = distanceMeters / elapsedSec;
          final computedKmh = computedMps * 3.6;

          if (computedKmh < 220.0) {
            final smoothed = (0.75 * computedKmh) + (0.25 * _currentTravelSpeedKmh);
            _currentTravelSpeedKmh = double.parse(smoothed.toStringAsFixed(1));
          }
        } else {
          _currentTravelSpeedKmh = 0.0;
        }
      }
    } else {
      _currentTravelSpeedKmh = 0.0;
    }

    if (_currentTravelSpeedKmh < 1.0) {
      _speedStatusLabel = 'Stationary';
    } else if (_currentTravelSpeedKmh < 7.5) {
      _speedStatusLabel = 'Walking';
    } else if (_currentTravelSpeedKmh < 25.0) {
      _speedStatusLabel = 'Cycling / Jogging';
    } else {
      _speedStatusLabel = 'Driving / In Transit';
    }

    _previousPosition = newPos;
    _previousPositionTime = now;
  }

  /// Ensures real-time location and signal updates run automatically while user moves
  void _ensureForegroundMovementWatcher() {
    if (_isTrackingActive || !_hasPermission || !_isLocationServiceEnabled || !_userConsent) {
      return;
    }
    if (_foregroundMoveSubscription != null) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );

    _foregroundMoveSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (pos) async {
        _currentPosition = pos;
        _updateTravelSpeed(pos);
        _networkProvider?.onSubscriberLocationUpdated(pos.latitude, pos.longitude);

        // Update reverse geocoded city if shifted noticeably
        try {
          _currentAddress = await _locationService.getAddressFromCoordinates(
            pos.latitude,
            pos.longitude,
          );
        } catch (_) {}

        notifyListeners();
      },
      onError: (e) {
        debugPrint('RoamEase: Foreground location watcher error: $e');
      },
    );
  }

  /// Proactively verifies location services and acquires the current GPS fix
  Future<void> checkAndFetchLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      _isLocationServiceEnabled = serviceEnabled;
      if (!serviceEnabled) {
        _isLoading = false;
        _errorMessage = 'Device location is turned off. Please enable GPS in settings.';
        notifyListeners();
        return;
      }

      LocationPermission perm = await _locationService.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await _locationService.requestPermission();
      }

      _hasPermission = (perm == LocationPermission.always || perm == LocationPermission.whileInUse);
      _isPermissionPermanentlyDenied = (perm == LocationPermission.deniedForever);

      if (_hasPermission) {
        final pos = await _locationService.getCurrentPosition();
        if (pos != null) {
          _currentPosition = pos;
          _updateTravelSpeed(pos);

          // Notify NetworkProvider immediately for distance computation & base station discovery
          _networkProvider?.onSubscriberLocationUpdated(pos.latitude, pos.longitude);

          _currentAddress = await _locationService.getAddressFromCoordinates(
            pos.latitude,
            pos.longitude,
          );

          if (_notificationProvider != null && _currentAddress != null) {
            _notificationProvider!.onSignificantLocationChanged(
              userId: _userId,
              city: _currentAddress!.city,
              area: _currentAddress!.area,
              userConsent: _userConsent,
            );
          }

          _ensureForegroundMovementWatcher();
        } else {
          _errorMessage = 'Waiting for satellite GPS lock. Step near an open window or outdoors.';
        }
      } else {
        _errorMessage = 'Location permission is required to detect roaming position.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Interactive permission request
  Future<bool> requestPermissionAndLocate() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      _isLocationServiceEnabled = serviceEnabled;
      if (!serviceEnabled) {
        await _locationService.openLocationSettings();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final perm = await _locationService.requestPermission();
      _hasPermission = (perm == LocationPermission.always || perm == LocationPermission.whileInUse);
      _isPermissionPermanentlyDenied = (perm == LocationPermission.deniedForever);

      if (_isPermissionPermanentlyDenied) {
        await _locationService.openAppSettings();
      }

      if (_hasPermission) {
        final pos = await _locationService.getCurrentPosition();
        if (pos != null) {
          _currentPosition = pos;
          _updateTravelSpeed(pos);
          _networkProvider?.onSubscriberLocationUpdated(pos.latitude, pos.longitude);

          _currentAddress = await _locationService.getAddressFromCoordinates(
            pos.latitude,
            pos.longitude,
          );

          if (_notificationProvider != null && _currentAddress != null) {
            _notificationProvider!.onSignificantLocationChanged(
              userId: _userId,
              city: _currentAddress!.city,
              area: _currentAddress!.area,
              userConsent: _userConsent,
            );
          }
          _ensureForegroundMovementWatcher();
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
    await checkAndFetchLocation();
  }

  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  /// Transparent start and stop tracking controls
  Future<void> toggleTracking({
    required String userId,
    required bool userConsent,
  }) async {
    if (!userConsent) {
      _errorMessage = 'Tracking requires subscriber location consent in profile settings.';
      notifyListeners();
      return;
    }

    if (_isTrackingActive) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _isTrackingActive = false;
      _currentTravelSpeedKmh = 0.0;
      _speedStatusLabel = 'Stationary';
      await StorageService.setTrackingActive(false);
      await NotificationService.showTrackingStatusNotification(
        isTracking: false,
        locationSummary: '',
      );
      _ensureForegroundMovementWatcher();
      notifyListeners();
    } else {
      if (!_hasPermission || !_isLocationServiceEnabled) {
        final granted = await requestPermissionAndLocate();
        if (!granted) return;
      }

      // Replace coarse foreground watcher with full continuous tracking stream
      await _foregroundMoveSubscription?.cancel();
      _foregroundMoveSubscription = null;

      _isTrackingActive = true;
      await StorageService.setTrackingActive(true);

      _positionSubscription = _locationService.getPositionStream().listen((pos) async {
        _currentPosition = pos;
        _updateTravelSpeed(pos);
        _networkProvider?.onSubscriberLocationUpdated(pos.latitude, pos.longitude);

        final address = await _locationService.getAddressFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        _currentAddress = address;

        await _saveWaypoint(
          userId: userId,
          latitude: pos.latitude,
          longitude: pos.longitude,
          altitude: pos.altitude,
          accuracy: pos.accuracy,
          speed: _currentTravelSpeedKmh / 3.6,
          address: address,
        );

        await NotificationService.showTrackingStatusNotification(
          isTracking: true,
          locationSummary: '${address.city}, ${address.area} (${_currentTravelSpeedKmh.toStringAsFixed(1)} km/h)',
        );

        notifyListeners();
      });

      notifyListeners();
    }
  }

  Future<void> _saveWaypoint({
    required String userId,
    required double latitude,
    required double longitude,
    required double altitude,
    required double accuracy,
    required double speed,
    required LocationAddressResult address,
  }) async {
    final net = _networkProvider?.currentNetwork;
    final record = LocationRecordModel(
      id: const Uuid().v4(),
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      accuracy: accuracy,
      speed: speed,
      address: address.fullAddress,
      city: address.city,
      area: address.area,
      country: address.country,
      postalCode: address.postalCode,
      timestamp: DateTime.now(),
      signalDbm: (net != null && net.signalStrengthDbm != -1) ? net.signalStrengthDbm : null,
      rsrp: net?.rsrp,
      networkType: net?.networkType,
      operatorName: net?.operatorName,
      signalQualityTier: net?.signalQualityTier,
    );

    _locationHistory.insert(0, record);
    await StorageService.saveLocalLocationRecord(record);
    await FirebaseService.saveLocationRecord(record);
  }

  /// Manual save current location waypoint
  Future<bool> saveCurrentLocation(String userId) async {
    if (_currentPosition == null) {
      await checkAndFetchLocation();
    }

    if (_currentPosition == null) return false;

    final pos = _currentPosition!;
    final address = _currentAddress ??
        await _locationService.getAddressFromCoordinates(pos.latitude, pos.longitude);

    await _saveWaypoint(
      userId: userId,
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      accuracy: pos.accuracy,
      speed: _currentTravelSpeedKmh / 3.6,
      address: address,
    );

    notifyListeners();
    return true;
  }

  Future<void> deleteRecord(String recordId) async {
    _locationHistory.removeWhere((r) => r.id == recordId);
    await FirebaseService.deleteLocationRecord(recordId);
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    _locationHistory.clear();
    await StorageService.clearLocalLocationHistory();
    notifyListeners();
  }

  Future<void> loadCloudLocationHistory(String userId) async {
    if (!FirebaseService.isInitialized) return;
    try {
      final list = await FirebaseService.fetchLocationHistory(userId);
      if (list.isNotEmpty) {
        _locationHistory = list;
        notifyListeners();
      }
    } catch (_) {}
  }
}

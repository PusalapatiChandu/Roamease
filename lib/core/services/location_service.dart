import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationAddressResult {
  final String fullAddress;
  final String city;
  final String area;
  final String country;
  final String postalCode;

  LocationAddressResult({
    required this.fullAddress,
    required this.city,
    required this.area,
    required this.country,
    required this.postalCode,
  });
}

class LocationService {
  final Geocoding _geocoding = Geocoding();

  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  /// Retrieves current position with graceful fallback cascade:
  /// 1. Verifies location service is enabled.
  /// 2. Requests permission if denied.
  /// 3. Checks last known position for instant responsiveness.
  /// 4. Tries high accuracy with 7s timeout.
  /// 5. Falls back to medium/low accuracy (cell/Wi-Fi) if indoors or cold GPS.
  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Quick last known position check for fast UI hydration
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    // High accuracy GPS fix attempt
    try {
      final highPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );
      return highPos;
    } catch (e) {
      debugPrint('RoamEase: High accuracy GPS timed out or failed ($e), falling back to medium accuracy...');
    }

    // Medium accuracy fallback (Cell-ID / Wi-Fi trilateration works reliably indoors)
    try {
      final mediumPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return mediumPos;
    } catch (_) {}

    // Return last known position if fresh fix could not be acquired
    return lastKnown;
  }

  /// Continuous GPS position stream for travel tracking with sensitive displacement filter
  Stream<Position> getPositionStream() {
    LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // Continuous updates for real-time travel speed calculation
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Reverse geocodes latitude/longitude coordinates into city, area, and street address
  Future<LocationAddressResult> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final List<Placemark> placemarks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(const Duration(seconds: 5));

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final city = place.locality?.isNotEmpty == true
            ? place.locality!
            : (place.subAdministrativeArea?.isNotEmpty == true
                ? place.subAdministrativeArea!
                : (place.administrativeArea ?? 'City'));

        final area = place.subLocality?.isNotEmpty == true
            ? place.subLocality!
            : (place.thoroughfare?.isNotEmpty == true
                ? place.thoroughfare!
                : (place.name ?? 'Area'));

        final country = place.country ?? '';
        final postalCode = place.postalCode ?? '';

        final parts = [
          if (place.name != null && place.name!.isNotEmpty) place.name,
          if (place.subLocality != null && place.subLocality!.isNotEmpty && place.subLocality != place.name)
            place.subLocality,
          if (place.locality != null && place.locality!.isNotEmpty) place.locality,
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty)
            place.administrativeArea,
          if (place.country != null && place.country!.isNotEmpty) place.country,
        ];

        final fullAddress = parts.join(', ');

        return LocationAddressResult(
          fullAddress: fullAddress.isNotEmpty
              ? fullAddress
              : 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
          city: city,
          area: area,
          country: country,
          postalCode: postalCode,
        );
      }
    } catch (e) {
      debugPrint('RoamEase: Reverse geocoding failed ($e), using coordinate fallbacks');
    }

    return LocationAddressResult(
      fullAddress: 'Lat: ${latitude.toStringAsFixed(5)}, Lng: ${longitude.toStringAsFixed(5)}',
      city: 'Current Location',
      area: 'GPS Coordinates',
      country: '',
      postalCode: '',
    );
  }
}

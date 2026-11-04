import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import 'location_history_screen.dart';
import 'cell_towers_screen.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() => _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  final bool _mapError = false;

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  IconData _getTravelIcon(String statusLabel) {
    switch (statusLabel) {
      case 'Walking':
        return Icons.directions_walk_rounded;
      case 'Cycling / Jogging':
        return Icons.directions_bike_rounded;
      case 'Driving / In Transit':
        return Icons.directions_car_rounded;
      default:
        return Icons.speed_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationProvider = Provider.of<LocationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final position = locationProvider.currentPosition;
    final address = locationProvider.currentAddress;
    final subscriber = authProvider.currentSubscriber;
    final userId = subscriber?.uid ?? 'guest_subscriber';
    final hasConsent = subscriber?.locationConsent ?? true;
    final isTracking = locationProvider.isTrackingActive;

    final LatLng subscriberLatLng = position != null
        ? LatLng(position.latitude, position.longitude)
        : const LatLng(37.7749, -122.4194); // default fallback

    final Set<Marker> markers = {
      if (position != null)
        Marker(
          markerId: const MarkerId('subscriber_location'),
          position: subscriberLatLng,
          infoWindow: InfoWindow(
            title: subscriber?.fullName ?? 'Subscriber Current Location',
            snippet: address?.fullAddress ?? Formatters.formatCoordinates(position.latitude, position.longitude),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
    };

    final Set<Circle> circles = {
      if (position != null)
        Circle(
          circleId: const CircleId('accuracy_circle'),
          center: subscriberLatLng,
          radius: position.accuracy.clamp(10.0, 500.0),
          fillColor: AppColors.primaryBlue.withOpacity(0.18),
          strokeColor: AppColors.primaryBlue.withOpacity(0.6),
          strokeWidth: 2,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriber Location'),
        actions: [
          IconButton(
            icon: locationProvider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh GPS Fix',
            onPressed: () {
              locationProvider.checkAndFetchLocation();
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Permitted Location History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LocationHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cell_tower_rounded),
            tooltip: 'Cell Towers',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CellTowersScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Location Services Disabled Banner (if device GPS is toggled OFF)
            if (!locationProvider.isLocationServiceEnabled) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.signalPoor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.signalPoor.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_off_rounded, color: AppColors.signalPoor, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Device GPS Location is Disabled',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.signalPoor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Turn on Location Services in your Android settings to detect real-time coordinates, calculate travel speed, and monitor roaming.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => locationProvider.openLocationSettings(),
                      icon: const Icon(Icons.settings_rounded, size: 16),
                      label: const Text('Turn On Location in Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.signalPoor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!locationProvider.hasPermission) ...[
              // B. Permission Required Banner (if permission not granted)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security_rounded, color: AppColors.primaryBlue, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Location Permission Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'RoamEase requires location permission to lock GPS satellites and log permitted movement waypoints.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => locationProvider.requestPermissionAndLocate(),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text('Grant Location Access'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Transparent Tracking Control Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: isTracking
                    ? AppColors.card5GGradient
                    : const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: isTracking
                        ? AppColors.cyan5G.withOpacity(0.3)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isTracking ? Icons.radar_rounded : Icons.location_disabled_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isTracking ? 'GPS Tracking Active' : 'Location Tracking Stopped',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isTracking
                              ? AppColors.signalExcellent
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isTracking ? 'ONLINE' : 'STANDBY',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTracking
                        ? 'Consent-based GPS waypoint recording is active. Updating coordinates and travel speed continuously as you move.'
                        : 'Tracking is paused. You can start transparent travel tracking to log route history and roaming towers.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            locationProvider.toggleTracking(
                              userId: userId,
                              userConsent: hasConsent,
                            );
                          },
                          icon: Icon(isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
                          label: Text(isTracking ? 'Stop Tracking' : 'Start GPS Tracking'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTracking ? AppColors.signalPoor : Colors.white,
                            foregroundColor: isTracking ? Colors.white : AppColors.navyDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final ok = await locationProvider.saveCurrentLocation(userId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Current waypoint saved to history!' : 'Unable to lock GPS fix. Please verify device location.'),
                                backgroundColor: ok ? AppColors.signalExcellent : AppColors.signalPoor,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.bookmark_add_rounded),
                        tooltip: 'Save Current Waypoint',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Interactive Map Container
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // Google Maps Widget
                    if (!_mapError && (Platform.isAndroid || Platform.isIOS))
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: subscriberLatLng,
                          zoom: 15.0,
                        ),
                        mapType: _currentMapType,
                        myLocationEnabled: locationProvider.hasPermission,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        markers: markers,
                        circles: circles,
                        onMapCreated: _onMapCreated,
                      )
                    else
                      Container(
                        color: isDark ? const Color(0xFF131D2E) : const Color(0xFFE2E8F0),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_rounded, size: 48, color: AppColors.primaryBlue.withOpacity(0.5)),
                              const SizedBox(height: 10),
                              Text(
                                position != null
                                    ? 'Map View Ready\n${Formatters.formatCoordinates(position.latitude, position.longitude)}'
                                    : 'Awaiting Satellite Fix...',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Set your Google Maps API key in AndroidManifest to enable vector tiles.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10, color: AppColors.textMutedDark),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Map Floating Controls
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: IconButton(
                              icon: Icon(
                                _currentMapType == MapType.satellite
                                    ? Icons.map_rounded
                                    : Icons.satellite_alt_rounded,
                                size: 20,
                              ),
                              tooltip: 'Toggle Satellite / Normal View',
                              onPressed: () {
                                setState(() {
                                  _currentMapType = _currentMapType == MapType.normal
                                      ? MapType.satellite
                                      : MapType.normal;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.my_location_rounded, size: 20, color: AppColors.primaryBlue),
                              tooltip: 'Recenter on Subscriber',
                              onPressed: () {
                                if (position != null && _mapController != null) {
                                  _mapController!.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(position.latitude, position.longitude),
                                      16.0,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map Status Tag
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkSurface : Colors.white).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: position != null ? AppColors.signalExcellent : AppColors.roamingWarning,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              position != null
                                  ? 'Accuracy ±${position.accuracy.toStringAsFixed(1)}m'
                                  : (locationProvider.isLoading ? 'Acquiring GPS fix...' : 'Waiting for GPS Fix'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Geographical Coordinates & Real-time Travel Speed
            Text(
              'GEOGRAPHICAL COORDINATES & TRAVEL SPEED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildCoordinateTile(
                    context,
                    label: 'Latitude',
                    value: position != null ? position.latitude.toStringAsFixed(6) : '--',
                    icon: Icons.north_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCoordinateTile(
                    context,
                    label: 'Longitude',
                    value: position != null ? position.longitude.toStringAsFixed(6) : '--',
                    icon: Icons.east_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCoordinateTile(
                    context,
                    label: 'Altitude',
                    value: position != null ? '${position.altitude.toStringAsFixed(1)} m' : '--',
                    icon: Icons.terrain_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCoordinateTile(
                    context,
                    label: 'Travel Speed',
                    value: position != null
                        ? '${locationProvider.currentTravelSpeedKmh.toStringAsFixed(1)} km/h'
                        : '--',
                    subValue: locationProvider.speedStatusLabel,
                    icon: _getTravelIcon(locationProvider.speedStatusLabel),
                    highlightColor: locationProvider.currentTravelSpeedKmh > 1.0
                        ? AppColors.signalExcellent
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 4. Reverse Geocoded Address Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded, color: AppColors.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'CURRENT CITY & ADMINISTRATIVE AREA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    address?.city.isNotEmpty == true ? address!.city : (position != null ? 'Detecting Area...' : 'Location Unavailable'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address?.fullAddress ?? (position != null ? Formatters.formatCoordinates(position.latitude, position.longitude) : 'Turn on device location and grant permission to view address.'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 5. Permitted Location History Quick Access
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PREVIOUSLY VISITED LOCATIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LocationHistoryScreen()),
                    );
                  },
                  child: const Text('Full History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (locationProvider.locationHistory.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Center(
                  child: Text(
                    'No location records yet.\nActivate "Start GPS Tracking" or tap "Save Waypoint".',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ),
              )
            else
              ...locationProvider.locationHistory.take(3).map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, color: AppColors.primaryBlue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.city.isNotEmpty ? '${item.city}, ${item.area}' : item.address,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${Formatters.formatCoordinates(item.latitude, item.longitude)} • ${Formatters.formatDateTime(item.timestamp)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinateTile(
    BuildContext context, {
    required String label,
    required String value,
    String? subValue,
    required IconData icon,
    Color? highlightColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlightColor?.withOpacity(0.4) ?? (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: highlightColor ?? AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: highlightColor,
                  ),
                ),
                if (subValue != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subValue,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: highlightColor ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

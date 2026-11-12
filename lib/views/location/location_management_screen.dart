import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/mapped_base_station_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/network_provider.dart';
import '../../widgets/base_station_details_sheet.dart';
import '../../widgets/opencellid_config_dialog.dart';
import 'location_history_screen.dart';
import 'cell_towers_screen.dart';

enum _MapViewMode { street, satellite, googleMaps }

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() => _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  final fm.MapController _mapController = fm.MapController();
  gmaps.GoogleMapController? _googleMapController;

  _MapViewMode _mapViewMode = _MapViewMode.street;
  bool _hasAutoSelectedMapMode = false;
  bool _showTowers = true;
  bool _showCoverage = true;
  bool _showAllTowersInList = false;
  String _generationFilter = 'All'; // 'All', '5G', '4G', 'Serving'
  double _currentZoom = 12.4;
  ll.LatLng? _lastCenteredPoint;

  double _zoomForRadius(double radiusMeters) {
    if (radiusMeters <= 3100) return 13.1;
    if (radiusMeters <= 4100) return 12.7;
    if (radiusMeters <= 5200) return 12.3;
    return 11.6;
  }

  void _fitRadiusView(double lat, double lng, double radiusMeters) {
    setState(() {
      _currentZoom = _zoomForRadius(radiusMeters);
    });
    _recenterMap(lat, lng);
  }

  @override
  void dispose() {
    _googleMapController?.dispose();
    super.dispose();
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

  void _recenterMap(double lat, double lng) {
    final point = ll.LatLng(lat, lng);
    if (_mapViewMode == _MapViewMode.googleMaps) {
      _googleMapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(lat, lng), _currentZoom),
      );
    } else {
      _mapController.move(point, _currentZoom);
    }
    _lastCenteredPoint = point;
  }

  void _cycleMapViewMode() {
    setState(() {
      switch (_mapViewMode) {
        case _MapViewMode.street:
          _mapViewMode = _MapViewMode.satellite;
          break;
        case _MapViewMode.satellite:
          _mapViewMode = _MapViewMode.googleMaps;
          break;
        case _MapViewMode.googleMaps:
          _mapViewMode = _MapViewMode.street;
          break;
      }
    });
  }

  String _mapModeLabel(_MapViewMode mode) {
    switch (mode) {
      case _MapViewMode.street:
        return 'OpenStreetMap';
      case _MapViewMode.satellite:
        return 'Satellite';
      case _MapViewMode.googleMaps:
        return 'Google Maps';
    }
  }

  List<MappedBaseStationModel> _filterStations(List<MappedBaseStationModel> all) {
    switch (_generationFilter) {
      case '5G':
        return all.where((s) => s.is5g).toList();
      case '4G':
        return all.where((s) => s.is4g).toList();
      case 'Serving':
        return all.where((s) => s.isServingCell || s.isNeighbourCell).toList();
      default:
        return all;
    }
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'Strong':
        return AppColors.signalExcellent;
      case 'Moderate':
        return AppColors.signalFair;
      case 'Weak':
        return AppColors.signalPoor;
      default:
        return AppColors.textMutedDark;
    }
  }

  Color _stationAccent(MappedBaseStationModel s) {
    if (s.isServingCell) return AppColors.signalExcellent;
    if (s.is5g) return AppColors.cyan5G;
    if (s.is4g) return AppColors.primaryBlue;
    return AppColors.accentIndigo;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationProvider = Provider.of<LocationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final networkProvider = Provider.of<NetworkProvider>(context);

    if (!_hasAutoSelectedMapMode && networkProvider.hasValidGoogleMapsKey) {
      _hasAutoSelectedMapMode = true;
      _mapViewMode = _MapViewMode.googleMaps;
    }

    final position = locationProvider.currentPosition;
    final address = locationProvider.currentAddress;
    final subscriber = authProvider.currentSubscriber;
    final userId = subscriber?.uid ?? 'guest_subscriber';
    final hasConsent = subscriber?.locationConsent ?? true;
    final isTracking = locationProvider.isTrackingActive;
    final network = networkProvider.currentNetwork;

    final allMappedStations = networkProvider.mappedBaseStations;
    final filteredStations = _filterStations(allMappedStations);
    final highlightedTarget = networkProvider.servingMappedStation ??
        (filteredStations.isNotEmpty ? filteredStations.first : null);

    final ll.LatLng subscriberPoint = position != null
        ? ll.LatLng(position.latitude, position.longitude)
        : const ll.LatLng(13.030349, 80.018116);

    // Auto-center once when fresh position arrives
    if (position != null) {
      final point = ll.LatLng(position.latitude, position.longitude);
      if (_lastCenteredPoint == null ||
          (_lastCenteredPoint!.latitude - point.latitude).abs() > 0.00008 ||
          (_lastCenteredPoint!.longitude - point.longitude).abs() > 0.00008) {
        _lastCenteredPoint = point;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (_mapViewMode == _MapViewMode.googleMaps) {
              _googleMapController?.animateCamera(
                gmaps.CameraUpdate.newLatLngZoom(
                  gmaps.LatLng(point.latitude, point.longitude),
                  _currentZoom,
                ),
              );
            } else {
              _mapController.move(point, _currentZoom);
            }
          }
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriber Location & Towers'),
        actions: [
          IconButton(
            icon: (locationProvider.isLoading || networkProvider.isScanningTowers)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh GPS & Rescan Base Stations',
            onPressed: () async {
              await locationProvider.checkAndFetchLocation();
              final pos = locationProvider.currentPosition;
              if (pos != null) {
                await networkProvider.scanNearbyBaseStations(
                  pos.latitude,
                  pos.longitude,
                  force: true,
                );
              }
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
            tooltip: 'Detected Cells & Towers List',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CellTowersScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Location Services Disabled Banner
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
                      'Turn on Location Services in Android settings to detect GPS coordinates, calculate distance to base stations, and measure travel speed.',
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
              // B. Permission Required Banner
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
                      'RoamEase requires location access to lock GPS satellites, identify serving/neighbouring cells, and map nearby 4G/5G towers.',
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
                        ? 'Consent-based GPS movement & signal telemetry active. Automatically updating coordinates, tower distances, and RF metrics.'
                        : 'Tracking paused. Tap Start GPS Tracking to log waypoints & measured signal coverage along your route.',
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
                                content: Text(ok
                                    ? 'Current waypoint & RF snapshot saved!'
                                    : 'Unable to lock GPS fix. Verify device location.'),
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

            const SizedBox(height: 14),

            // 2. Radius Selector (3–5 km) + Map Generation Filter Strip
            Row(
              children: [
                Text(
                  'SCAN RADIUS:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                ...[3000.0, 4000.0, 5000.0].map((r) {
                  final bool isSel = (networkProvider.towerSearchRadiusMeters - r).abs() < 250;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${(r / 1000).round()} km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : AppColors.navyDark),
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.cyan5G,
                      onSelected: (_) async {
                        _fitRadiusView(subscriberPoint.latitude, subscriberPoint.longitude, r);
                        await networkProvider.setTowerSearchRadius(r);
                      },
                    ),
                  );
                }),
                const Spacer(),
                Text(
                  '${allMappedStations.length} in ${(networkProvider.towerSearchRadiusMeters / 1000).toStringAsFixed(0)} km',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'All (${allMappedStations.length})', isDark),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '5G',
                    '5G (${allMappedStations.where((s) => s.is5g).length})',
                    isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '4G',
                    '4G (${allMappedStations.where((s) => s.is4g).length})',
                    isDark,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    'Serving',
                    'Active Cells',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.tune_rounded, size: 15, color: AppColors.primaryBlue),
                    label: Text(
                      networkProvider.openCellIdApiKey.isEmpty ? 'Add API Key' : 'OpenCelliD OK',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => showOpenCellIdConfigDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 3. Interactive Map Container (OSM / Satellite / Google Maps + Towers + Estimated Coverage)
            Container(
              height: 350,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    if (_mapViewMode == _MapViewMode.googleMaps)
                      _buildGoogleMapView(
                        subscriberPoint: subscriberPoint,
                        positionAccuracy: position?.accuracy ?? 30.0,
                        searchRadiusMeters: networkProvider.towerSearchRadiusMeters,
                        stations: filteredStations,
                        highlightedTarget: highlightedTarget,
                        subscriberName: subscriber?.fullName ?? 'Subscriber',
                      )
                    else
                      _buildFlutterMapView(
                        subscriberPoint: subscriberPoint,
                        positionAccuracy: position?.accuracy,
                        searchRadiusMeters: networkProvider.towerSearchRadiusMeters,
                        stations: filteredStations,
                        highlightedTarget: highlightedTarget,
                        locationHistory: locationProvider.locationHistory,
                        subscriberName: subscriber?.fullName ?? 'Subscriber',
                        cityName: address?.city ?? 'GPS Fix',
                      ),

                    // Top-Left Coordinates & Tower Distance Pill
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF0F172A) : Colors.white).withOpacity(0.92),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.gps_fixed_rounded, size: 13, color: AppColors.cyan5G),
                                const SizedBox(width: 6),
                                Text(
                                  position != null
                                      ? '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
                                      : 'Acquiring GPS...',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          if (highlightedTarget != null) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => showBaseStationDetailsSheet(context, highlightedTarget),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: (isDark ? const Color(0xFF0F172A) : Colors.white).withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cell_tower_rounded,
                                      size: 13,
                                      color: _stationAccent(highlightedTarget),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${highlightedTarget.isServingCell ? "Serving" : "Nearest"}: ${highlightedTarget.formattedDistance}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (_mapViewMode == _MapViewMode.googleMaps &&
                              !networkProvider.hasValidGoogleMapsKey) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 230),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.roamingWarning.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Google Maps requires an API key in AndroidManifest.xml. Tap layer icon for Street/Satellite tiles.',
                                style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Map Floating Controls (Layer Switch, Coverage Toggle, Towers Toggle, Recenter, Zoom)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Column(
                        children: [
                          _buildMapFloatingButton(
                            icon: _mapViewMode == _MapViewMode.street
                                ? Icons.satellite_alt_rounded
                                : (_mapViewMode == _MapViewMode.satellite
                                    ? Icons.public_rounded
                                    : Icons.map_rounded),
                            tooltip: 'Switch Map Layer (${_mapModeLabel(_mapViewMode)})',
                            isDark: isDark,
                            onPressed: _cycleMapViewMode,
                          ),
                          const SizedBox(height: 6),
                          _buildMapFloatingButton(
                            icon: Icons.radar_rounded,
                            tooltip: _showCoverage ? 'Hide Estimated Coverage' : 'Show Estimated Coverage',
                            isDark: isDark,
                            iconColor: _showCoverage ? AppColors.cyan5G : null,
                            onPressed: () => setState(() => _showCoverage = !_showCoverage),
                          ),
                          const SizedBox(height: 6),
                          _buildMapFloatingButton(
                            icon: Icons.cell_tower_rounded,
                            tooltip: _showTowers ? 'Hide Tower Pins' : 'Show Tower Pins',
                            isDark: isDark,
                            iconColor: _showTowers ? AppColors.signalExcellent : null,
                            onPressed: () => setState(() => _showTowers = !_showTowers),
                          ),
                          const SizedBox(height: 6),
                          _buildMapFloatingButton(
                            icon: Icons.my_location_rounded,
                            tooltip: 'Center on My Location',
                            isDark: isDark,
                            iconColor: AppColors.primaryBlue,
                            onPressed: () {
                              if (position != null) {
                                _recenterMap(position.latitude, position.longitude);
                              } else {
                                locationProvider.checkAndFetchLocation();
                              }
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildMapFloatingButton(
                            icon: Icons.zoom_out_map_rounded,
                            tooltip: 'Fit ${(networkProvider.towerSearchRadiusMeters / 1000).toStringAsFixed(0)} km Tower Radius',
                            isDark: isDark,
                            iconColor: AppColors.cyan5G,
                            onPressed: () => _fitRadiusView(
                              subscriberPoint.latitude,
                              subscriberPoint.longitude,
                              networkProvider.towerSearchRadiusMeters,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildMapFloatingButton(
                            icon: Icons.add_rounded,
                            tooltip: 'Zoom In',
                            isDark: isDark,
                            onPressed: () {
                              setState(() {
                                _currentZoom = (_currentZoom + 1.0).clamp(3.0, 18.5);
                                _recenterMap(subscriberPoint.latitude, subscriberPoint.longitude);
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildMapFloatingButton(
                            icon: Icons.remove_rounded,
                            tooltip: 'Zoom Out',
                            isDark: isDark,
                            onPressed: () {
                              setState(() {
                                _currentZoom = (_currentZoom - 1.0).clamp(3.0, 18.5);
                                _recenterMap(subscriberPoint.latitude, subscriberPoint.longitude);
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Bottom-Left Accuracy & Engine Tag
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF0F172A) : Colors.white).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                                  ? '±${position.accuracy.toStringAsFixed(1)}m • ${_mapModeLabel(_mapViewMode)}'
                                  : (locationProvider.isLoading ? 'Locking GPS...' : 'Waiting GPS'),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom-Right Coverage Legend Pill
                    if (_showCoverage)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF0F172A) : Colors.white).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: const Text(
                            'Rings: Est. Coverage',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Geographical Coordinates & Real-time Travel Speed
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

            const SizedBox(height: 18),

            // 5. Integrated Live Signal Quality & Nearby Base Stations Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LIVE CELLULAR SIGNAL & NEARBY TOWERS',
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
                      MaterialPageRoute(builder: (_) => const CellTowersScreen()),
                    );
                  },
                  child: Text(
                    'All Cells (${networkProvider.cellTowers.length})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            // Active Measured Signal Strip (Strong / Moderate / Weak + RSRP / RSRQ / SINR)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _tierColor(network.signalQualityTier).withOpacity(0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${network.operatorName} • ${network.networkType}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: _tierColor(network.signalQualityTier).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'SIGNAL: ${network.signalQualityTier.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _tierColor(network.signalQualityTier),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniTelemetry('Measured', Formatters.formatDbm(network.signalStrengthDbm), isDark),
                      _miniTelemetry('RSRP', network.rsrp != null ? '${network.rsrp} dBm' : 'Unavailable', isDark),
                      _miniTelemetry('RSRQ', network.rsrq != null ? '${network.rsrq} dB' : 'Unavailable', isDark),
                      _miniTelemetry('SINR', network.sinr != null ? '${network.sinr} dB' : 'Unavailable', isDark),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Serving Cell: ${networkProvider.servingCell?.cellId ?? network.servingCellId ?? "Unavailable"} • '
                    'Neighbours: ${networkProvider.neighbouringCells.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Mapped Base Stations List (sorted by live distance)
            if (networkProvider.isScanningTowers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Querying nearby 4G/5G base station datasets...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              )
            else if (filteredStations.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No Mapped Towers in Current Filter / Radius',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      networkProvider.towerUnavailableNotes.isNotEmpty
                          ? networkProvider.towerUnavailableNotes.join(' ')
                          : 'No verified OpenStreetMap / beaconDB / OpenCelliD towers found within current scan radius.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => showOpenCellIdConfigDialog(context),
                          icon: const Icon(Icons.key_rounded, size: 15),
                          label: const Text('Configure OpenCelliD / Radius', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else ...[
              ...filteredStations
                  .take(_showAllTowersInList ? filteredStations.length : 10)
                  .map((station) {
                final accent = _stationAccent(station);
                return InkWell(
                  onTap: () {
                    _recenterMap(station.latitude, station.longitude);
                    showBaseStationDetailsSheet(context, station);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: station.isServingCell
                            ? AppColors.signalExcellent.withOpacity(0.55)
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            station.is5g ? Icons.flash_on_rounded : Icons.cell_tower_rounded,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      station.operatorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      station.generation,
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: accent),
                                    ),
                                  ),
                                  if (station.isServingCell) ...[
                                    const SizedBox(width: 4),
                                    const Text(
                                      '• SERVING',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.signalExcellent,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${station.source} • Coverage: ${station.estimatedCoverageTier}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              station.formattedDistance,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: accent,
                              ),
                            ),
                            const Text(
                              'Tap details',
                              style: TextStyle(fontSize: 9, color: AppColors.primaryBlue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (filteredStations.length > 10)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showAllTowersInList = !_showAllTowersInList),
                    icon: Icon(
                      _showAllTowersInList ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _showAllTowersInList
                          ? 'Show Fewer Towers'
                          : 'Show All ${filteredStations.length} Towers (${(networkProvider.towerSearchRadiusMeters / 1000).toStringAsFixed(0)} km Radius)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  'Coverage Disclaimer: Tower coverage radii and path-loss estimates are calculated from external dataset bounds (${networkProvider.towerSourcesUsed.join(", ")}) and propagation models — separate from actual measured dBm/RSRP.',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 6. Reverse Geocoded Address Card
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
                    address?.city.isNotEmpty == true
                        ? address!.city
                        : (position != null ? 'Detecting Area...' : 'Location Unavailable'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address?.fullAddress ??
                        (position != null
                            ? Formatters.formatCoordinates(position.latitude, position.longitude)
                            : 'Turn on device location and grant permission to view address.'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 7. Permitted Location History Quick Access
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

  Widget _buildFlutterMapView({
    required ll.LatLng subscriberPoint,
    required double? positionAccuracy,
    required double searchRadiusMeters,
    required List<MappedBaseStationModel> stations,
    required MappedBaseStationModel? highlightedTarget,
    required List locationHistory,
    required String subscriberName,
    required String cityName,
  }) {
    final bool isSat = _mapViewMode == _MapViewMode.satellite;

    return fm.FlutterMap(
      mapController: _mapController,
      options: fm.MapOptions(
        initialCenter: subscriberPoint,
        initialZoom: _currentZoom,
        minZoom: 3.0,
        maxZoom: 18.5,
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) {
            _currentZoom = camera.zoom;
          }
        },
      ),
      children: [
        fm.TileLayer(
          urlTemplate: isSat
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.roamease',
          maxZoom: 19,
        ),

        // 1. Search Radius Ring (3–5 km) + Estimated Coverage Circles + GPS Accuracy Circle
        fm.CircleLayer(
          circles: [
            fm.CircleMarker(
              point: subscriberPoint,
              radius: searchRadiusMeters,
              useRadiusInMeter: true,
              color: AppColors.cyan5G.withOpacity(0.04),
              borderColor: AppColors.cyan5G.withOpacity(0.65),
              borderStrokeWidth: 2.0,
            ),
            if (_showCoverage)
              ...stations.map((s) {
                final c = _stationAccent(s);
                return fm.CircleMarker(
                  point: ll.LatLng(s.latitude, s.longitude),
                  radius: s.estimatedCoverageRadiusMeters,
                  useRadiusInMeter: true,
                  color: c.withOpacity(0.11),
                  borderColor: c.withOpacity(0.45),
                  borderStrokeWidth: s.isServingCell ? 2.0 : 1.2,
                );
              }),
            if (positionAccuracy != null)
              fm.CircleMarker(
                point: subscriberPoint,
                radius: positionAccuracy.clamp(15.0, 300.0),
                useRadiusInMeter: true,
                color: AppColors.primaryBlue.withOpacity(0.18),
                borderColor: AppColors.primaryBlue.withOpacity(0.75),
                borderStrokeWidth: 2,
              ),
          ],
        ),

        // 2. Distance Polyline from Subscriber GPS to Serving / Nearest Base Station
        if (_showTowers && highlightedTarget != null)
          fm.PolylineLayer(
            polylines: [
              fm.Polyline(
                points: [
                  subscriberPoint,
                  ll.LatLng(highlightedTarget.latitude, highlightedTarget.longitude),
                ],
                color: _stationAccent(highlightedTarget).withOpacity(0.85),
                strokeWidth: 2.5,
              ),
            ],
          ),

        // 3. Subscriber's Own Measured Signal Trail Waypoints
        if (_showCoverage)
          fm.MarkerLayer(
            markers: locationHistory
                .where((r) => r.signalQualityTier != null)
                .take(25)
                .map<fm.Marker>((r) {
              final dotColor = _tierColor(r.signalQualityTier!);
              return fm.Marker(
                point: ll.LatLng(r.latitude, r.longitude),
                width: 14,
                height: 14,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              );
            }).toList(),
          ),

        // 4. Nearby Mapped 4G & 5G Base Station Markers
        if (_showTowers)
          fm.MarkerLayer(
            markers: stations.map((station) {
              final accent = _stationAccent(station);
              return fm.Marker(
                point: ll.LatLng(station.latitude, station.longitude),
                width: 112,
                height: 58,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => showBaseStationDetailsSheet(context, station),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                        ),
                        child: Icon(
                          station.is5g ? Icons.flash_on_rounded : Icons.cell_tower_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.88),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_shortOperator(station.operatorName)} • ${_shortGen(station.generation)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

        // 5. Subscriber Glowing Avatar Pin Marker
        fm.MarkerLayer(
          markers: [
            fm.Marker(
              point: subscriberPoint,
              width: 64,
              height: 64,
              alignment: Alignment.center,
              child: _buildSubscriberMarker(subscriberName, cityName),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoogleMapView({
    required ll.LatLng subscriberPoint,
    required double positionAccuracy,
    required double searchRadiusMeters,
    required List<MappedBaseStationModel> stations,
    required MappedBaseStationModel? highlightedTarget,
    required String subscriberName,
  }) {
    final Set<gmaps.Marker> markers = {
      gmaps.Marker(
        markerId: const gmaps.MarkerId('subscriber_gps'),
        position: gmaps.LatLng(subscriberPoint.latitude, subscriberPoint.longitude),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
        infoWindow: gmaps.InfoWindow(
          title: subscriberName,
          snippet: 'Current GPS Position',
        ),
      ),
      if (_showTowers)
        ...stations.map((station) {
          final double hue = station.isServingCell
              ? gmaps.BitmapDescriptor.hueGreen
              : (station.is5g
                  ? gmaps.BitmapDescriptor.hueCyan
                  : gmaps.BitmapDescriptor.hueAzure);
          return gmaps.Marker(
            markerId: gmaps.MarkerId(station.id),
            position: gmaps.LatLng(station.latitude, station.longitude),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: gmaps.InfoWindow(
              title: '${station.operatorName} (${station.generation})',
              snippet: '${station.formattedDistance} • Tap for telemetry',
              onTap: () => showBaseStationDetailsSheet(context, station),
            ),
            onTap: () => showBaseStationDetailsSheet(context, station),
          );
        }),
    };

    final Set<gmaps.Circle> circles = {
      gmaps.Circle(
        circleId: const gmaps.CircleId('search_radius_ring'),
        center: gmaps.LatLng(subscriberPoint.latitude, subscriberPoint.longitude),
        radius: searchRadiusMeters,
        fillColor: AppColors.cyan5G.withOpacity(0.04),
        strokeColor: AppColors.cyan5G.withOpacity(0.7),
        strokeWidth: 2,
      ),
      gmaps.Circle(
        circleId: const gmaps.CircleId('gps_accuracy'),
        center: gmaps.LatLng(subscriberPoint.latitude, subscriberPoint.longitude),
        radius: positionAccuracy.clamp(15.0, 300.0),
        fillColor: AppColors.primaryBlue.withOpacity(0.18),
        strokeColor: AppColors.primaryBlue,
        strokeWidth: 2,
      ),
      if (_showCoverage)
        ...stations.map((s) {
          final c = _stationAccent(s);
          return gmaps.Circle(
            circleId: gmaps.CircleId('cov_${s.id}'),
            center: gmaps.LatLng(s.latitude, s.longitude),
            radius: s.estimatedCoverageRadiusMeters,
            fillColor: c.withOpacity(0.12),
            strokeColor: c.withOpacity(0.5),
            strokeWidth: 1,
          );
        }),
    };

    final Set<gmaps.Polyline> polylines = {
      if (_showTowers && highlightedTarget != null)
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('serving_vector'),
          points: [
            gmaps.LatLng(subscriberPoint.latitude, subscriberPoint.longitude),
            gmaps.LatLng(highlightedTarget.latitude, highlightedTarget.longitude),
          ],
          color: _stationAccent(highlightedTarget),
          width: 3,
          patterns: [gmaps.PatternItem.dash(12), gmaps.PatternItem.gap(8)],
        ),
    };

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(subscriberPoint.latitude, subscriberPoint.longitude),
        zoom: _currentZoom,
      ),
      onMapCreated: (controller) => _googleMapController = controller,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: markers,
      circles: circles,
      polylines: polylines,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }

  String _shortOperator(String op) {
    if (op.contains('Jio')) return 'Jio';
    if (op.contains('Airtel')) return 'Airtel';
    if (op.contains('Vodafone Idea')) return 'Vi';
    if (op.contains('Unspecified')) return 'Tower';
    return op.length > 10 ? '${op.substring(0, 9)}..' : op;
  }

  String _shortGen(String gen) {
    if (gen.contains('5G')) return '5G';
    if (gen.contains('4G')) return '4G';
    if (gen.contains('3G')) return '3G';
    if (gen.contains('2G')) return '2G';
    return 'Mast';
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark) {
    final bool selected = _generationFilter == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: selected ? Colors.white : (isDark ? Colors.white70 : AppColors.navyDark),
        ),
      ),
      selected: selected,
      selectedColor: AppColors.primaryBlue,
      onSelected: (_) => setState(() => _generationFilter = filterKey),
    );
  }

  Widget _miniTelemetry(String label, String val, bool isDark) {
    final bool unavail = val == 'Unavailable';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: unavail
                ? (isDark ? AppColors.textMutedDark : AppColors.textMutedLight)
                : (isDark ? Colors.white : AppColors.navyDark),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriberMarker(String name, String city) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cyan5G.withOpacity(0.25),
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryBlue.withOpacity(0.35),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.heroGradient,
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: const Icon(
            Icons.person_pin_circle_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildMapFloatingButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: iconColor),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
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

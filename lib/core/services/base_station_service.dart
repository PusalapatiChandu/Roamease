import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../models/cell_tower_model.dart';
import '../../models/mapped_base_station_model.dart';
import '../utils/telecom_utils.dart';

class BaseStationFetchResult {
  final List<MappedBaseStationModel> mappedStations;
  final List<CellTowerModel> enrichedDetectedCells;
  final List<String> sourcesUsed;
  final List<String> unavailableNotes;
  final DateTime fetchedAt;

  BaseStationFetchResult({
    required this.mappedStations,
    required this.enrichedDetectedCells,
    required this.sourcesUsed,
    required this.unavailableNotes,
    required this.fetchedAt,
  });
}

class BaseStationService {
  static const Duration _httpTimeout = Duration(seconds: 12);

  /// Fetches real mapped 4G/5G base stations within [searchRadiusMeters] (typically 3000m–5000m)
  /// around [latitude], [longitude] from open/authorized telecom datasets and matches them
  /// against live [detectedCells] reported by Android Telephony APIs.
  ///
  /// Never fabricates tower locations. Any cell whose coordinates cannot be
  /// resolved in an external database remains marked with unavailable coordinates.
  Future<BaseStationFetchResult> fetchNearbyBaseStations({
    required double latitude,
    required double longitude,
    required List<CellTowerModel> detectedCells,
    String openCellIdApiKey = '',
    double searchRadiusMeters = 5000.0,
  }) async {
    final List<MappedBaseStationModel> collectedStations = [];
    final List<String> sourcesUsed = [];
    final List<String> unavailableNotes = [];
    final Map<String, CellTowerModel> enrichedByKey = {};

    for (final cell in detectedCells) {
      enrichedByKey[_cellKey(cell)] = cell;
    }

    // Launch all independent network lookups in parallel for fast multi-kilometer scans
    final Future<List<MappedBaseStationModel>> openCellFuture =
        openCellIdApiKey.trim().isNotEmpty
            ? _queryOpenCellIdWithinRadius(
                latitude: latitude,
                longitude: longitude,
                radiusMeters: searchRadiusMeters,
                detectedCells: detectedCells,
                apiKey: openCellIdApiKey.trim(),
              )
            : Future.value(<MappedBaseStationModel>[]);

    final Future<List<MappedBaseStationModel>> beaconFuture =
        _lookupDetectedCellsInBeaconDb(
      detectedCells: detectedCells,
      subscriberLat: latitude,
      subscriberLng: longitude,
    );

    final Future<List<MappedBaseStationModel>> overpassFuture =
        _queryOverpassPhysicalTowers(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: searchRadiusMeters,
    );

    final results = await Future.wait([
      openCellFuture,
      beaconFuture,
      overpassFuture,
    ]);

    final ocStations = results[0];
    final beaconStations = results[1];
    final osmStations = results[2];

    if (openCellIdApiKey.trim().isEmpty) {
      unavailableNotes.add(
        'OpenCelliD API key not configured (optional free key unlocks regional 4G/5G Cell-ID towers within ${(searchRadiusMeters / 1000).toStringAsFixed(1)} km).',
      );
    } else if (ocStations.isNotEmpty) {
      collectedStations.addAll(ocStations);
      sourcesUsed.add('OpenCelliD Live API');
    } else {
      unavailableNotes.add(
        'OpenCelliD returned no mapped cells in ${(searchRadiusMeters / 1000).toStringAsFixed(1)} km.',
      );
    }

    if (beaconStations.isNotEmpty) {
      collectedStations.addAll(beaconStations);
      sourcesUsed.add('beaconDB Cell Dataset');
    } else if (detectedCells.isNotEmpty && openCellIdApiKey.trim().isEmpty) {
      unavailableNotes.add('Serving/neighbour Cell-IDs had no mapped coordinates in beaconDB.');
    }

    if (osmStations.isNotEmpty) {
      collectedStations.addAll(osmStations);
      sourcesUsed.add('OpenStreetMap Telecom Registry');
    } else {
      unavailableNotes.add(
        'No OSM communication towers mapped within ${(searchRadiusMeters / 1000).toStringAsFixed(1)} km.',
      );
    }

    // Deduplicate, match live Android Cell Telemetry, and strictly respect searchRadiusMeters
    final List<MappedBaseStationModel> finalStations = [];
    for (final station in collectedStations) {
      CellTowerModel? matchedCell;
      for (final cell in detectedCells) {
        if (station.cellId != null &&
            station.cellId == cell.cellId &&
            (station.mcc == null || cell.mcc == null || station.mcc == cell.mcc)) {
          matchedCell = cell;
          break;
        }
      }

      final double dist = Geolocator.distanceBetween(
        latitude,
        longitude,
        station.latitude,
        station.longitude,
      );

      final bool isServing = matchedCell?.isRegistered ?? station.isServingCell;

      // Filter strictly to selected 3-5 km radius (always retain Serving Cell if resolved slightly beyond border)
      if (!isServing && dist > searchRadiusMeters) {
        continue;
      }

      final duplicateIdx = finalStations.indexWhere((existing) {
        if (existing.cellId != null && station.cellId != null && existing.cellId == station.cellId) {
          return true;
        }
        final d = Geolocator.distanceBetween(
          existing.latitude,
          existing.longitude,
          station.latitude,
          station.longitude,
        );
        return d < 25.0 && existing.generation == station.generation;
      });

      final enrichedStation = station.copyWith(
        distanceMeters: dist,
        isServingCell: isServing,
        isNeighbourCell: matchedCell != null ? !matchedCell.isRegistered : station.isNeighbourCell,
        measuredDbm: matchedCell?.dbm ?? station.measuredDbm,
        measuredRsrp: matchedCell?.rsrp ?? station.measuredRsrp,
        measuredRsrq: matchedCell?.rsrq ?? station.measuredRsrq,
        measuredSinr: matchedCell?.sinr ?? station.measuredSinr,
        timingAdvance: matchedCell?.timingAdvance ?? station.timingAdvance,
        pci: matchedCell?.pci ?? station.pci,
        arfcn: matchedCell?.arfcn ?? station.arfcn,
      );

      if (matchedCell != null) {
        enrichedByKey[_cellKey(matchedCell)] = matchedCell.copyWith(
          mappedLat: enrichedStation.latitude,
          mappedLng: enrichedStation.longitude,
          estimatedRangeMeters: enrichedStation.estimatedCoverageRadiusMeters.round(),
          distanceMeters: dist,
          coordinateSource: enrichedStation.source,
        );
      }

      if (duplicateIdx == -1) {
        finalStations.add(enrichedStation);
      } else {
        final existing = finalStations[duplicateIdx];
        if ((enrichedStation.isServingCell && !existing.isServingCell) ||
            (existing.cellId == null && enrichedStation.cellId != null)) {
          finalStations[duplicateIdx] = enrichedStation;
        }
      }
    }

    // Sort: Serving Cell first, then Nearest Distance outward up to 3–5 km
    finalStations.sort((a, b) {
      if (a.isServingCell != b.isServingCell) {
        return a.isServingCell ? -1 : 1;
      }
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    return BaseStationFetchResult(
      mappedStations: finalStations,
      enrichedDetectedCells: detectedCells.map((c) => enrichedByKey[_cellKey(c)] ?? c).toList(),
      sourcesUsed: sourcesUsed,
      unavailableNotes: unavailableNotes,
      fetchedAt: DateTime.now(),
    );
  }

  /// Recomputes live Haversine distances for mapped stations as the subscriber moves.
  List<MappedBaseStationModel> recalculateDistances({
    required double subscriberLat,
    required double subscriberLng,
    required List<MappedBaseStationModel> stations,
  }) {
    final updated = stations.map((s) {
      final d = Geolocator.distanceBetween(
        subscriberLat,
        subscriberLng,
        s.latitude,
        s.longitude,
      );
      return s.copyWith(distanceMeters: d);
    }).toList();

    updated.sort((a, b) {
      if (a.isServingCell != b.isServingCell) {
        return a.isServingCell ? -1 : 1;
      }
      return a.distanceMeters.compareTo(b.distanceMeters);
    });
    return updated;
  }

  String _cellKey(CellTowerModel c) => '${c.type}_${c.mcc}_${c.mnc}_${c.tac}_${c.cellId}_${c.pci}';

  Future<List<MappedBaseStationModel>> _queryOpenCellIdWithinRadius({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required List<CellTowerModel> detectedCells,
    required String apiKey,
  }) async {
    final List<MappedBaseStationModel> collected = [];

    // OpenCelliD limits each /cell/getInArea query to <= 4 sq km (~1.78 km x 1.78 km).
    // For a 3–5 km radius, query center + 4 cardinal adjacent tiles (~1.9 km step) in parallel.
    const double stepLat = 0.017; // ~1.89 km
    final double cosLat = math.cos(latitude * math.pi / 180.0).abs().clamp(0.35, 1.0);
    final double stepLon = 0.017 / cosLat;

    final List<List<double>> tileCenters = [
      [latitude, longitude],
      if (radiusMeters >= 2500) ...[
        [latitude + stepLat, longitude],
        [latitude - stepLat, longitude],
        [latitude, longitude + stepLon],
        [latitude, longitude - stepLon],
      ],
    ];

    try {
      final tileFutures = tileCenters.map((center) => _querySingleOpenCellIdTile(
            tileLat: center[0],
            tileLon: center[1],
            subscriberLat: latitude,
            subscriberLng: longitude,
            apiKey: apiKey,
          ));

      final tileResults = await Future.wait(tileFutures);
      for (final list in tileResults) {
        collected.addAll(list);
      }

      // Also resolve serving/neighbouring detected cells precisely if not yet matched
      final cellsToLookup = detectedCells
          .where((c) => c.mcc != null && c.mnc != null && c.tac != null && c.cellId != 'Unavailable')
          .take(8)
          .toList();

      final cellFutures = cellsToLookup
          .where((cell) => !collected.any((s) => s.cellId == cell.cellId && s.mcc == cell.mcc))
          .map((cell) => _lookupCellInOpenCellId(
                cell: cell,
                subscriberLat: latitude,
                subscriberLng: longitude,
                apiKey: apiKey,
              ));

      final resolvedCells = await Future.wait(cellFutures);
      for (final item in resolvedCells) {
        if (item != null) collected.add(item);
      }
    } catch (e) {
      debugPrint('RoamEase: OpenCelliD multi-tile scan error: $e');
    }

    return collected;
  }

  Future<List<MappedBaseStationModel>> _querySingleOpenCellIdTile({
    required double tileLat,
    required double tileLon,
    required double subscriberLat,
    required double subscriberLng,
    required String apiKey,
  }) async {
    try {
      const double deltaLat = 0.0082; // ~1.82 km height
      final double cosLat = math.cos(tileLat * math.pi / 180.0).abs().clamp(0.35, 1.0);
      final double deltaLon = 0.0082 / cosLat;

      final String bbox =
          '${(tileLat - deltaLat).toStringAsFixed(6)},'
          '${(tileLon - deltaLon).toStringAsFixed(6)},'
          '${(tileLat + deltaLat).toStringAsFixed(6)},'
          '${(tileLon + deltaLon).toStringAsFixed(6)}';

      final uri = Uri.parse(
        'https://opencellid.org/cell/getInArea?key=${Uri.encodeQueryComponent(apiKey)}&BBOX=$bbox&format=json&limit=50',
      );

      final response = await http.get(uri, headers: {'User-Agent': 'RoamEase/1.0'}).timeout(_httpTimeout);
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['cells'] is! List) return [];

      final List<MappedBaseStationModel> list = [];
      for (final raw in decoded['cells'] as List) {
        if (raw is! Map) continue;
        final double? lat = (raw['lat'] as num?)?.toDouble();
        final double? lon = (raw['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final String radioRaw = raw['radio']?.toString().toUpperCase() ?? 'LTE';
        final String gen = _normalizeRadio(radioRaw);
        final String mcc = raw['mcc']?.toString() ?? '';
        final String mnc = raw['mnc']?.toString() ?? '';
        final int? lac = (raw['lac'] as num?)?.toInt();
        final String cellId = raw['cellid']?.toString() ?? 'N/A';
        final int range = (raw['range'] as num?)?.toInt() ?? 0;

        final opName = TelecomUtils.resolveOperatorFromMccMnc(mcc, mnc) ??
            (mcc.isNotEmpty ? 'Carrier $mcc-$mnc' : 'Operator Unspecified');

        final double dist = Geolocator.distanceBetween(subscriberLat, subscriberLng, lat, lon);
        final double covRadius = range > 50
            ? range.toDouble()
            : TelecomUtils.estimateReferenceCoverageRadiusMeters(generation: gen);

        list.add(
          MappedBaseStationModel(
            id: 'oc_${mcc}_${mnc}_$cellId',
            latitude: lat,
            longitude: lon,
            operatorName: opName,
            generation: gen,
            source: 'OpenCelliD Live API',
            cellId: cellId,
            tac: lac,
            mcc: mcc,
            mnc: mnc,
            distanceMeters: dist,
            estimatedCoverageRadiusMeters: covRadius,
            coverageDatasetLabel: range > 50
                ? 'OpenCelliD Reported Range (Estimated)'
                : '3GPP Macro Reference Footprint (Estimated)',
          ),
        );
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<MappedBaseStationModel?> _lookupCellInOpenCellId({
    required CellTowerModel cell,
    required double subscriberLat,
    required double subscriberLng,
    required String apiKey,
  }) async {
    try {
      final radio = _toOpenCellIdRadio(cell.type);
      final uri = Uri.parse(
        'https://opencellid.org/cell/get?key=${Uri.encodeQueryComponent(apiKey)}'
        '&mcc=${cell.mcc}&mnc=${cell.mnc}&lac=${cell.tac}&cellid=${cell.cellId}'
        '${radio != null ? '&radio=$radio' : ''}&format=json',
      );

      final response = await http.get(uri, headers: {'User-Agent': 'RoamEase/1.0'}).timeout(_httpTimeout);
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final double? lat = (decoded['lat'] as num?)?.toDouble();
      final double? lon = (decoded['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;

      final int range = (decoded['range'] as num?)?.toInt() ?? 0;
      final double dist = Geolocator.distanceBetween(subscriberLat, subscriberLng, lat, lon);
      final double covRadius = range > 50
          ? range.toDouble()
          : TelecomUtils.estimateReferenceCoverageRadiusMeters(generation: cell.type, arfcn: cell.arfcn);

      return MappedBaseStationModel(
        id: 'oc_cell_${cell.mcc}_${cell.mnc}_${cell.cellId}',
        latitude: lat,
        longitude: lon,
        operatorName: cell.resolvedOperatorName,
        generation: cell.type,
        source: 'OpenCelliD Live API',
        cellId: cell.cellId,
        tac: cell.tac,
        pci: cell.pci,
        mcc: cell.mcc,
        mnc: cell.mnc,
        arfcn: cell.arfcn,
        isServingCell: cell.isRegistered,
        isNeighbourCell: !cell.isRegistered,
        distanceMeters: dist,
        measuredDbm: cell.dbm != -1 ? cell.dbm : null,
        measuredRsrp: cell.rsrp,
        measuredRsrq: cell.rsrq,
        measuredSinr: cell.sinr,
        timingAdvance: cell.timingAdvance,
        estimatedCoverageRadiusMeters: covRadius,
        coverageDatasetLabel: range > 50
            ? 'OpenCelliD Reported Range (Estimated)'
            : '3GPP Macro Reference Footprint (Estimated)',
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<MappedBaseStationModel>> _lookupDetectedCellsInBeaconDb({
    required List<CellTowerModel> detectedCells,
    required double subscriberLat,
    required double subscriberLng,
  }) async {
    final candidates = detectedCells
        .where((c) =>
            c.mcc != null &&
            c.mnc != null &&
            c.tac != null &&
            c.cellId != 'Unavailable' &&
            int.tryParse(c.mcc!) != null &&
            int.tryParse(c.mnc!) != null &&
            int.tryParse(c.cellId) != null)
        .take(10)
        .toList();

    if (candidates.isEmpty) return [];

    final futures = candidates.map((cell) async {
      final radioType = _toIchnaeaRadio(cell.type);
      if (radioType == null) return null;

      try {
        final payload = jsonEncode({
          'considerIp': false,
          'fallbacks': {'ipf': false},
          'cellTowers': [
            {
              'radioType': radioType,
              'mobileCountryCode': int.parse(cell.mcc!),
              'mobileNetworkCode': int.parse(cell.mnc!),
              'locationAreaCode': cell.tac!,
              'cellId': int.parse(cell.cellId),
            }
          ],
        });

        final response = await http
            .post(
              Uri.parse('https://api.beacondb.net/v1/geolocate'),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'RoamEase/1.0',
              },
              body: payload,
            )
            .timeout(_httpTimeout);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['location'] is Map) {
            final loc = decoded['location'] as Map;
            final double? lat = (loc['lat'] as num?)?.toDouble();
            final double? lng = (loc['lng'] as num?)?.toDouble();
            final double accuracy = (decoded['accuracy'] as num?)?.toDouble() ?? 1500.0;

            if (lat != null && lng != null && accuracy <= 12000.0) {
              final double dist = Geolocator.distanceBetween(subscriberLat, subscriberLng, lat, lng);
              if (dist <= 35000.0) {
                return MappedBaseStationModel(
                  id: 'bdb_${cell.mcc}_${cell.mnc}_${cell.cellId}',
                  latitude: lat,
                  longitude: lng,
                  operatorName: cell.resolvedOperatorName,
                  generation: cell.type,
                  source: 'beaconDB Cell Dataset',
                  cellId: cell.cellId,
                  tac: cell.tac,
                  pci: cell.pci,
                  mcc: cell.mcc,
                  mnc: cell.mnc,
                  arfcn: cell.arfcn,
                  isServingCell: cell.isRegistered,
                  isNeighbourCell: !cell.isRegistered,
                  distanceMeters: dist,
                  measuredDbm: cell.dbm != -1 ? cell.dbm : null,
                  measuredRsrp: cell.rsrp,
                  measuredRsrq: cell.rsrq,
                  measuredSinr: cell.sinr,
                  timingAdvance: cell.timingAdvance,
                  estimatedCoverageRadiusMeters: accuracy.clamp(250.0, 5000.0),
                  coverageDatasetLabel: 'beaconDB Estimated Cell Footprint',
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('RoamEase: beaconDB lookup failed for cell ${cell.cellId}: $e');
      }
      return null;
    });

    final resolved = await Future.wait(futures);
    return resolved.whereType<MappedBaseStationModel>().toList();
  }

  Future<List<MappedBaseStationModel>> _queryOverpassPhysicalTowers({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final r = radiusMeters.round().clamp(1500, 10000);
    final latStr = latitude.toStringAsFixed(6);
    final lonStr = longitude.toStringAsFixed(6);

    // Query nodes, ways, and relations (nwr) with `out center` so both point masts
    // and compound/rooftop telecom structures within 3–5 km are retrieved.
    final query = '[out:json][timeout:12];'
        '('
        'nwr["man_made"="mast"]["tower:type"="communication"](around:$r,$latStr,$lonStr);'
        'nwr["man_made"="tower"]["tower:type"="communication"](around:$r,$latStr,$lonStr);'
        'nwr["man_made"="communications_tower"](around:$r,$latStr,$lonStr);'
        'nwr["communication:mobile_phone"="yes"](around:$r,$latStr,$lonStr);'
        'nwr["telecom"~"base_station|antenna|mast|tower"](around:$r,$latStr,$lonStr);'
        ');'
        'out center 120;';

    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
      'https://lz4.overpass-api.de/api/interpreter',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': 'RoamEase/1.0',
              },
              body: {'data': query},
            )
            .timeout(_httpTimeout);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['elements'] is List) {
            return _parseOverpassElements(
              decoded['elements'] as List,
              latitude,
              longitude,
            );
          }
        }
      } catch (e) {
        debugPrint('RoamEase: Overpass endpoint $endpoint failed: $e');
      }
    }

    return [];
  }

  List<MappedBaseStationModel> _parseOverpassElements(
    List elements,
    double subscriberLat,
    double subscriberLng,
  ) {
    final List<MappedBaseStationModel> list = [];

    for (final el in elements) {
      if (el is! Map) continue;
      final Map? center = el['center'] is Map ? el['center'] as Map : null;
      final double? lat = (el['lat'] as num?)?.toDouble() ?? (center?['lat'] as num?)?.toDouble();
      final double? lon = (el['lon'] as num?)?.toDouble() ?? (center?['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final Map tags = (el['tags'] is Map) ? el['tags'] as Map : const {};
      final String id = el['id']?.toString() ?? '${lat}_$lon';

      // Extract operator ONLY if genuinely tagged in OpenStreetMap
      final String rawOp = (tags['operator'] ?? tags['network'] ?? tags['brand'] ?? tags['name'] ?? '').toString().trim();
      final String operatorName = rawOp.isNotEmpty ? rawOp : 'Operator Unspecified';

      // Extract generation ONLY if tagged in OpenStreetMap
      final bool is5g = tags['communication:5g'] == 'yes' || tags['communication:nr'] == 'yes';
      final bool is4g = tags['communication:lte'] == 'yes' || tags['communication:4g'] == 'yes';
      final bool is3g = tags['communication:umts'] == 'yes' || tags['communication:3g'] == 'yes';
      final bool is2g = tags['communication:gsm'] == 'yes' || tags['communication:2g'] == 'yes';

      String generation;
      if (is5g && is4g) {
        generation = '4G / 5G NR';
      } else if (is5g) {
        generation = '5G NR';
      } else if (is4g) {
        generation = '4G LTE';
      } else if (is3g) {
        generation = '3G UMTS';
      } else if (is2g) {
        generation = '2G GSM';
      } else {
        generation = 'Cellular Mast (Gen Unspecified)';
      }

      final double dist = Geolocator.distanceBetween(subscriberLat, subscriberLng, lat, lon);
      final double estRadius = TelecomUtils.estimateReferenceCoverageRadiusMeters(generation: generation);

      list.add(
        MappedBaseStationModel(
          id: 'osm_$id',
          latitude: lat,
          longitude: lon,
          operatorName: operatorName,
          generation: generation,
          source: 'OpenStreetMap Telecom Registry',
          distanceMeters: dist,
          estimatedCoverageRadiusMeters: estRadius,
          coverageDatasetLabel: '3GPP Macro Reference Footprint (Estimated)',
        ),
      );
    }

    return list;
  }

  String _normalizeRadio(String raw) {
    if (raw == 'NR' || raw.contains('5G')) return '5G NR';
    if (raw == 'LTE' || raw.contains('4G')) return '4G LTE';
    if (raw == 'UMTS' || raw.contains('3G')) return '3G WCDMA';
    if (raw == 'GSM' || raw.contains('2G')) return '2G GSM';
    return raw;
  }

  String? _toOpenCellIdRadio(String type) {
    final t = type.toUpperCase();
    if (t.contains('5G') || t.contains('NR')) return 'NR';
    if (t.contains('4G') || t.contains('LTE')) return 'LTE';
    if (t.contains('3G') || t.contains('WCDMA')) return 'UMTS';
    if (t.contains('2G') || t.contains('GSM')) return 'GSM';
    return null;
  }

  String? _toIchnaeaRadio(String type) {
    final t = type.toUpperCase();
    if (t.contains('5G') || t.contains('NR')) return 'nr';
    if (t.contains('4G') || t.contains('LTE')) return 'lte';
    if (t.contains('3G') || t.contains('WCDMA')) return 'wcdma';
    if (t.contains('2G') || t.contains('GSM')) return 'gsm';
    return null;
  }
}

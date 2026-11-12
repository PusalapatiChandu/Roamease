import '../core/utils/telecom_utils.dart';

/// Represents a real mapped mobile base station retrieved from an authorized/open
/// telecom dataset (OpenCelliD, beaconDB, or OpenStreetMap Telecom Registry),
/// optionally matched against the phone's live Serving / Neighbouring Cell telemetry.
class MappedBaseStationModel {
  final String id;
  final double latitude;
  final double longitude;
  final String operatorName;
  final String generation; // '5G NR', '4G LTE', '3G WCDMA', '2G GSM', 'Unspecified Gen'
  final String source; // Data provenance label

  // Cell Identifiers (null / unavailable if physical mast lacks logical IDs)
  final String? cellId;
  final int? tac;
  final int? pci;
  final String? mcc;
  final String? mnc;
  final int? arfcn;

  // Association with live Android Telephony detection
  final bool isServingCell;
  final bool isNeighbourCell;

  // Live Distance from subscriber's current GPS coordinate
  final double distanceMeters;

  // Actual Measured RF Signal (populated ONLY when matched with detected Telephony cell)
  final int? measuredDbm;
  final int? measuredRsrp;
  final int? measuredRsrq;
  final int? measuredSinr;
  final int? timingAdvance;

  // Estimated Coverage Dataset Attributes (strictly separated from actual measured RF)
  final double estimatedCoverageRadiusMeters;
  final String coverageDatasetLabel;

  MappedBaseStationModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.operatorName,
    required this.generation,
    required this.source,
    this.cellId,
    this.tac,
    this.pci,
    this.mcc,
    this.mnc,
    this.arfcn,
    this.isServingCell = false,
    this.isNeighbourCell = false,
    required this.distanceMeters,
    this.measuredDbm,
    this.measuredRsrp,
    this.measuredRsrq,
    this.measuredSinr,
    this.timingAdvance,
    required this.estimatedCoverageRadiusMeters,
    required this.coverageDatasetLabel,
  });

  bool get is5g => generation.toUpperCase().contains('5G') || generation.toUpperCase().contains('NR');
  bool get is4g => generation.toUpperCase().contains('4G') || generation.toUpperCase().contains('LTE');
  bool get hasMeasuredSignal =>
      (measuredRsrp != null && measuredRsrp != -1) ||
      (measuredDbm != null && measuredDbm != -1);

  /// Measured quality classification ('Strong', 'Moderate', 'Weak', or 'Unavailable').
  String get measuredSignalTier => TelecomUtils.classifySignalQuality(
        rsrp: measuredRsrp,
        dbm: measuredDbm,
      );

  /// Estimated path-loss signal based ONLY on distance & generation (strictly labeled Estimated).
  int get estimatedPathLossDbm => TelecomUtils.estimatePathLossDbm(
        distanceMeters: distanceMeters,
        generation: generation,
      );

  /// Estimated coverage quality at subscriber's current distance (NOT measured RF).
  String get estimatedCoverageTier {
    if (distanceMeters <= estimatedCoverageRadiusMeters * 0.40) {
      return 'Strong (Est.)';
    } else if (distanceMeters <= estimatedCoverageRadiusMeters * 0.85) {
      return 'Moderate (Est.)';
    } else if (distanceMeters <= estimatedCoverageRadiusMeters * 1.25) {
      return 'Weak Edge (Est.)';
    } else {
      return 'Fringe / Outside Radius (Est.)';
    }
  }

  String get formattedDistance => TelecomUtils.formatDistance(distanceMeters);

  String? get bandDescription => TelecomUtils.resolveBandFromArfcn(arfcn, generation);

  MappedBaseStationModel copyWith({
    double? distanceMeters,
    bool? isServingCell,
    bool? isNeighbourCell,
    int? measuredDbm,
    int? measuredRsrp,
    int? measuredRsrq,
    int? measuredSinr,
    int? timingAdvance,
    int? pci,
    int? arfcn,
  }) {
    return MappedBaseStationModel(
      id: id,
      latitude: latitude,
      longitude: longitude,
      operatorName: operatorName,
      generation: generation,
      source: source,
      cellId: cellId,
      tac: tac,
      pci: pci ?? this.pci,
      mcc: mcc,
      mnc: mnc,
      arfcn: arfcn ?? this.arfcn,
      isServingCell: isServingCell ?? this.isServingCell,
      isNeighbourCell: isNeighbourCell ?? this.isNeighbourCell,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      measuredDbm: measuredDbm ?? this.measuredDbm,
      measuredRsrp: measuredRsrp ?? this.measuredRsrp,
      measuredRsrq: measuredRsrq ?? this.measuredRsrq,
      measuredSinr: measuredSinr ?? this.measuredSinr,
      timingAdvance: timingAdvance ?? this.timingAdvance,
      estimatedCoverageRadiusMeters: estimatedCoverageRadiusMeters,
      coverageDatasetLabel: coverageDatasetLabel,
    );
  }
}


import '../core/utils/telecom_utils.dart';

class CellTowerModel {
  final String cellId;
  final String type; // '5G NR', '4G LTE', '3G WCDMA', '2G GSM'
  final int dbm;
  final int level;
  final int? asu;
  final int? tac;
  final int? pci;
  final bool isRegistered;

  // Extended Telephony & Optional Geolocation Lookup Fields
  final String? mcc;
  final String? mnc;
  final String? operatorName;
  final int? rsrp;
  final int? rsrq;
  final int? sinr;
  final int? cqi;
  final int? timingAdvance;
  final int? arfcn;
  final int? bandwidthKhz;

  // Physical Location (Populated ONLY if verified in OpenCelliD / beaconDB)
  final double? mappedLat;
  final double? mappedLng;
  final int? estimatedRangeMeters;
  final double? distanceMeters;
  final String? coordinateSource;

  CellTowerModel({
    required this.cellId,
    required this.type,
    required this.dbm,
    required this.level,
    this.asu,
    this.tac,
    this.pci,
    this.isRegistered = false,
    this.mcc,
    this.mnc,
    this.operatorName,
    this.rsrp,
    this.rsrq,
    this.sinr,
    this.cqi,
    this.timingAdvance,
    this.arfcn,
    this.bandwidthKhz,
    this.mappedLat,
    this.mappedLng,
    this.estimatedRangeMeters,
    this.distanceMeters,
    this.coordinateSource,
  });

  String get signalQualityTier => TelecomUtils.classifySignalQuality(
        rsrp: rsrp,
        dbm: dbm,
        level: level,
      );

  String get resolvedOperatorName {
    if (operatorName != null && operatorName!.isNotEmpty) return operatorName!;
    return TelecomUtils.resolveOperatorFromMccMnc(mcc, mnc) ?? 'Operator Unavailable';
  }

  String? get bandDescription => TelecomUtils.resolveBandFromArfcn(arfcn, type);

  String get cellRoleLabel => isRegistered ? 'SERVING CELL' : 'NEIGHBOUR CELL';

  bool get hasMappedCoordinates => mappedLat != null && mappedLng != null;

  CellTowerModel copyWith({
    double? mappedLat,
    double? mappedLng,
    int? estimatedRangeMeters,
    double? distanceMeters,
    String? coordinateSource,
  }) {
    return CellTowerModel(
      cellId: cellId,
      type: type,
      dbm: dbm,
      level: level,
      asu: asu,
      tac: tac,
      pci: pci,
      isRegistered: isRegistered,
      mcc: mcc,
      mnc: mnc,
      operatorName: operatorName,
      rsrp: rsrp,
      rsrq: rsrq,
      sinr: sinr,
      cqi: cqi,
      timingAdvance: timingAdvance,
      arfcn: arfcn,
      bandwidthKhz: bandwidthKhz,
      mappedLat: mappedLat ?? this.mappedLat,
      mappedLng: mappedLng ?? this.mappedLng,
      estimatedRangeMeters: estimatedRangeMeters ?? this.estimatedRangeMeters,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      coordinateSource: coordinateSource ?? this.coordinateSource,
    );
  }

  factory CellTowerModel.fromMap(Map<dynamic, dynamic> map) {
    final String? mccStr = map['mcc']?.toString();
    final String? mncStr = map['mnc']?.toString();
    final String? explicitOp = map['operatorName']?.toString();
    final String? resolvedOp = (explicitOp != null && explicitOp.isNotEmpty)
        ? explicitOp
        : TelecomUtils.resolveOperatorFromMccMnc(mccStr, mncStr);

    return CellTowerModel(
      cellId: map['cellId']?.toString() ?? 'Unavailable',
      type: map['type']?.toString() ?? 'Cell Tower',
      dbm: (map['dbm'] as num?)?.toInt() ?? -1,
      level: (map['level'] as num?)?.toInt() ?? 0,
      asu: (map['asu'] as num?)?.toInt(),
      tac: (map['tac'] as num?)?.toInt() ?? (map['lac'] as num?)?.toInt(),
      pci: (map['pci'] as num?)?.toInt(),
      isRegistered: map['isRegistered'] == true,
      mcc: mccStr,
      mnc: mncStr,
      operatorName: resolvedOp,
      rsrp: (map['rsrp'] as num?)?.toInt(),
      rsrq: (map['rsrq'] as num?)?.toInt(),
      sinr: (map['sinr'] as num?)?.toInt(),
      cqi: (map['cqi'] as num?)?.toInt(),
      timingAdvance: (map['timingAdvance'] as num?)?.toInt(),
      arfcn: (map['arfcn'] as num?)?.toInt(),
      bandwidthKhz: (map['bandwidthKhz'] as num?)?.toInt(),
    );
  }
}

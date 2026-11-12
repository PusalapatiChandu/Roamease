import '../core/utils/telecom_utils.dart';

class NetworkInfoModel {
  final String networkType; // '5G NR', '5G NSA', '4G LTE', '3G', '2G', 'Wi-Fi', 'No Connection'
  final String operatorName;
  final int signalStrengthDbm;
  final int signalLevel; // 0 to 4
  final int signalAsu;
  final bool isRoaming;
  final bool isWifi;
  final bool isCellular;
  final bool isConnected;
  final bool is5gSupported;
  final String simState;
  final DateTime timestamp;

  // Serving Cell RF & Identity Telemetry (nullable when unavailable/unsupported)
  final int? rsrp;
  final int? rsrq;
  final int? sinr;
  final int? cqi;
  final int? timingAdvance;
  final String? servingCellId;
  final int? servingTac;
  final int? servingPci;
  final String? mcc;
  final String? mnc;
  final int? arfcn;
  final int? bandwidthKhz;

  NetworkInfoModel({
    required this.networkType,
    required this.operatorName,
    required this.signalStrengthDbm,
    required this.signalLevel,
    required this.signalAsu,
    required this.isRoaming,
    required this.isWifi,
    required this.isCellular,
    required this.isConnected,
    required this.is5gSupported,
    required this.simState,
    required this.timestamp,
    this.rsrp,
    this.rsrq,
    this.sinr,
    this.cqi,
    this.timingAdvance,
    this.servingCellId,
    this.servingTac,
    this.servingPci,
    this.mcc,
    this.mnc,
    this.arfcn,
    this.bandwidthKhz,
  });

  String get qualityLabel {
    if (!isConnected) return 'Disconnected';
    if (signalStrengthDbm == -1 && signalLevel == 0) return 'Active';
    if (signalLevel >= 4 || (signalStrengthDbm != -1 && signalStrengthDbm >= -85)) {
      return 'Excellent';
    } else if (signalLevel == 3 || (signalStrengthDbm != -1 && signalStrengthDbm >= -98)) {
      return 'Good';
    } else if (signalLevel == 2 || (signalStrengthDbm != -1 && signalStrengthDbm >= -109)) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }

  /// Authoritative Strong / Moderate / Weak / Unavailable classification based on measured values.
  String get signalQualityTier => TelecomUtils.classifySignalQuality(
        rsrp: rsrp,
        dbm: signalStrengthDbm,
        level: signalLevel,
        isConnected: isConnected,
      );

  /// Resolved frequency band name when ARFCN is reported by modem.
  String? get bandDescription => TelecomUtils.resolveBandFromArfcn(arfcn, networkType);

  bool get isPoorConnection {
    if (!isConnected) return true;
    if (signalStrengthDbm != -1 && signalStrengthDbm <= -112) return true;
    if (signalLevel == 1 && signalStrengthDbm == -1) return true;
    return false;
  }

  bool get is5gActive => networkType.toUpperCase().contains('5G');

  Map<String, dynamic> toMap() {
    return {
      'networkType': networkType,
      'operatorName': operatorName,
      'signalStrengthDbm': signalStrengthDbm,
      'signalLevel': signalLevel,
      'signalAsu': signalAsu,
      'isRoaming': isRoaming,
      'isWifi': isWifi,
      'isCellular': isCellular,
      'isConnected': isConnected,
      'is5gSupported': is5gSupported,
      'simState': simState,
      'timestamp': timestamp.toIso8601String(),
      if (rsrp != null) 'rsrp': rsrp,
      if (rsrq != null) 'rsrq': rsrq,
      if (sinr != null) 'sinr': sinr,
      if (cqi != null) 'cqi': cqi,
      if (timingAdvance != null) 'timingAdvance': timingAdvance,
      if (servingCellId != null) 'servingCellId': servingCellId,
      if (servingTac != null) 'servingTac': servingTac,
      if (servingPci != null) 'servingPci': servingPci,
      if (mcc != null) 'mcc': mcc,
      if (mnc != null) 'mnc': mnc,
      if (arfcn != null) 'arfcn': arfcn,
      if (bandwidthKhz != null) 'bandwidthKhz': bandwidthKhz,
    };
  }

  factory NetworkInfoModel.fromMap(Map<String, dynamic> map) {
    return NetworkInfoModel(
      networkType: map['networkType'] ?? 'Unknown',
      operatorName: map['operatorName'] ?? 'Unknown',
      signalStrengthDbm: (map['signalStrengthDbm'] as num?)?.toInt() ?? -1,
      signalLevel: (map['signalLevel'] as num?)?.toInt() ?? 0,
      signalAsu: (map['signalAsu'] as num?)?.toInt() ?? -1,
      isRoaming: map['isRoaming'] == true,
      isWifi: map['isWifi'] == true,
      isCellular: map['isCellular'] == true,
      isConnected: map['isConnected'] == true,
      is5gSupported: map['is5gSupported'] == true,
      simState: map['simState'] ?? 'Unknown',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      rsrp: (map['rsrp'] as num?)?.toInt(),
      rsrq: (map['rsrq'] as num?)?.toInt(),
      sinr: (map['sinr'] as num?)?.toInt(),
      cqi: (map['cqi'] as num?)?.toInt(),
      timingAdvance: (map['timingAdvance'] as num?)?.toInt(),
      servingCellId: map['servingCellId']?.toString(),
      servingTac: (map['servingTac'] as num?)?.toInt(),
      servingPci: (map['servingPci'] as num?)?.toInt(),
      mcc: map['mcc']?.toString(),
      mnc: map['mnc']?.toString(),
      arfcn: (map['arfcn'] as num?)?.toInt(),
      bandwidthKhz: (map['bandwidthKhz'] as num?)?.toInt(),
    );
  }

  factory NetworkInfoModel.initial() {
    return NetworkInfoModel(
      networkType: 'Detecting...',
      operatorName: 'Scanning SIM...',
      signalStrengthDbm: -1,
      signalLevel: 0,
      signalAsu: -1,
      isRoaming: false,
      isWifi: false,
      isCellular: false,
      isConnected: false,
      is5gSupported: true,
      simState: 'Checking',
      timestamp: DateTime.now(),
    );
  }
}

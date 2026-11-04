class NetworkInfoModel {
  final String networkType; // '5G', '4G LTE', '3G', '2G', 'Wi-Fi', 'No Connection'
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

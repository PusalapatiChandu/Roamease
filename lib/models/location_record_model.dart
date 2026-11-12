class LocationRecordModel {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final String address;
  final String city;
  final String area;
  final String country;
  final String postalCode;
  final DateTime timestamp;

  // Optional measured cellular signal snapshot at this coordinate
  final int? signalDbm;
  final int? rsrp;
  final String? networkType;
  final String? operatorName;
  final String? signalQualityTier;

  LocationRecordModel({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speed,
    required this.address,
    required this.city,
    required this.area,
    required this.country,
    required this.postalCode,
    required this.timestamp,
    this.signalDbm,
    this.rsrp,
    this.networkType,
    this.operatorName,
    this.signalQualityTier,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'address': address,
      'city': city,
      'area': area,
      'country': country,
      'postalCode': postalCode,
      'timestamp': timestamp.toIso8601String(),
      if (signalDbm != null) 'signalDbm': signalDbm,
      if (rsrp != null) 'rsrp': rsrp,
      if (networkType != null) 'networkType': networkType,
      if (operatorName != null) 'operatorName': operatorName,
      if (signalQualityTier != null) 'signalQualityTier': signalQualityTier,
    };
  }

  factory LocationRecordModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return LocationRecordModel(
      id: docId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] ?? 'Unknown location',
      city: map['city'] ?? '',
      area: map['area'] ?? '',
      country: map['country'] ?? '',
      postalCode: map['postalCode'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      signalDbm: (map['signalDbm'] as num?)?.toInt(),
      rsrp: (map['rsrp'] as num?)?.toInt(),
      networkType: map['networkType']?.toString(),
      operatorName: map['operatorName']?.toString(),
      signalQualityTier: map['signalQualityTier']?.toString(),
    );
  }
}

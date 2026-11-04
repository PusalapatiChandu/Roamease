class SpeedTestResultModel {
  final String id;
  final double downloadSpeedMbps;
  final double uploadSpeedMbps;
  final int pingMs;
  final int jitterMs;
  final String networkType;
  final String operatorName;
  final DateTime timestamp;

  SpeedTestResultModel({
    required this.id,
    required this.downloadSpeedMbps,
    required this.uploadSpeedMbps,
    required this.pingMs,
    required this.jitterMs,
    required this.networkType,
    required this.operatorName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'downloadSpeedMbps': downloadSpeedMbps,
      'uploadSpeedMbps': uploadSpeedMbps,
      'pingMs': pingMs,
      'jitterMs': jitterMs,
      'networkType': networkType,
      'operatorName': operatorName,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SpeedTestResultModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return SpeedTestResultModel(
      id: docId ?? map['id'] ?? '',
      downloadSpeedMbps: (map['downloadSpeedMbps'] as num?)?.toDouble() ?? 0.0,
      uploadSpeedMbps: (map['uploadSpeedMbps'] as num?)?.toDouble() ?? 0.0,
      pingMs: (map['pingMs'] as num?)?.toInt() ?? 0,
      jitterMs: (map['jitterMs'] as num?)?.toInt() ?? 0,
      networkType: map['networkType'] ?? 'Unknown',
      operatorName: map['operatorName'] ?? 'Unknown',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

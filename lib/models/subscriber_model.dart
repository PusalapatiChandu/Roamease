class SubscriberModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String operatorName;
  final String simType; // '5G' or '4G'
  final String deviceModel;
  final bool locationConsent;
  final bool isRoaming;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SubscriberModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.operatorName,
    required this.simType,
    required this.deviceModel,
    required this.locationConsent,
    this.isRoaming = false,
    required this.createdAt,
    this.updatedAt,
  });

  SubscriberModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phone,
    String? operatorName,
    String? simType,
    String? deviceModel,
    bool? locationConsent,
    bool? isRoaming,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriberModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      operatorName: operatorName ?? this.operatorName,
      simType: simType ?? this.simType,
      deviceModel: deviceModel ?? this.deviceModel,
      locationConsent: locationConsent ?? this.locationConsent,
      isRoaming: isRoaming ?? this.isRoaming,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'operatorName': operatorName,
      'simType': simType,
      'deviceModel': deviceModel,
      'locationConsent': locationConsent,
      'isRoaming': isRoaming,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory SubscriberModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return SubscriberModel(
      uid: docId ?? map['uid'] ?? '',
      fullName: map['fullName'] ?? 'Subscriber',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      operatorName: map['operatorName'] ?? 'Unknown Operator',
      simType: map['simType'] ?? '5G',
      deviceModel: map['deviceModel'] ?? 'Unknown Device',
      locationConsent: map['locationConsent'] ?? false,
      isRoaming: map['isRoaming'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,
    );
  }
}

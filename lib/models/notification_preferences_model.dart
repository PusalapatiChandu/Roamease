class NotificationPreferencesModel {
  final String userId;
  final bool allNotificationsEnabled;
  final bool networkChanges;
  final bool connectionState;
  final bool poorSignal;
  final bool significantLocation;
  final bool roamingAlerts;
  final bool dataUsageAlerts;
  final bool securityAlerts;
  final double dataLimitGb;
  final double currentDataUsedMb;

  NotificationPreferencesModel({
    required this.userId,
    this.allNotificationsEnabled = true,
    this.networkChanges = true,
    this.connectionState = true,
    this.poorSignal = true,
    this.significantLocation = true,
    this.roamingAlerts = true,
    this.dataUsageAlerts = true,
    this.securityAlerts = true,
    this.dataLimitGb = 10.0,
    this.currentDataUsedMb = 0.0,
  });

  NotificationPreferencesModel copyWith({
    String? userId,
    bool? allNotificationsEnabled,
    bool? networkChanges,
    bool? connectionState,
    bool? poorSignal,
    bool? significantLocation,
    bool? roamingAlerts,
    bool? dataUsageAlerts,
    bool? securityAlerts,
    double? dataLimitGb,
    double? currentDataUsedMb,
  }) {
    return NotificationPreferencesModel(
      userId: userId ?? this.userId,
      allNotificationsEnabled: allNotificationsEnabled ?? this.allNotificationsEnabled,
      networkChanges: networkChanges ?? this.networkChanges,
      connectionState: connectionState ?? this.connectionState,
      poorSignal: poorSignal ?? this.poorSignal,
      significantLocation: significantLocation ?? this.significantLocation,
      roamingAlerts: roamingAlerts ?? this.roamingAlerts,
      dataUsageAlerts: dataUsageAlerts ?? this.dataUsageAlerts,
      securityAlerts: securityAlerts ?? this.securityAlerts,
      dataLimitGb: dataLimitGb ?? this.dataLimitGb,
      currentDataUsedMb: currentDataUsedMb ?? this.currentDataUsedMb,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'allNotificationsEnabled': allNotificationsEnabled,
      'networkChanges': networkChanges,
      'connectionState': connectionState,
      'poorSignal': poorSignal,
      'significantLocation': significantLocation,
      'roamingAlerts': roamingAlerts,
      'dataUsageAlerts': dataUsageAlerts,
      'securityAlerts': securityAlerts,
      'dataLimitGb': dataLimitGb,
      'currentDataUsedMb': currentDataUsedMb,
    };
  }

  factory NotificationPreferencesModel.fromMap(Map<String, dynamic> map, {String? userId}) {
    return NotificationPreferencesModel(
      userId: userId ?? map['userId'] ?? 'guest',
      allNotificationsEnabled: map['allNotificationsEnabled'] ?? true,
      networkChanges: map['networkChanges'] ?? true,
      connectionState: map['connectionState'] ?? true,
      poorSignal: map['poorSignal'] ?? true,
      significantLocation: map['significantLocation'] ?? true,
      roamingAlerts: map['roamingAlerts'] ?? true,
      dataUsageAlerts: map['dataUsageAlerts'] ?? true,
      securityAlerts: map['securityAlerts'] ?? true,
      dataLimitGb: (map['dataLimitGb'] as num?)?.toDouble() ?? 10.0,
      currentDataUsedMb: (map['currentDataUsedMb'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory NotificationPreferencesModel.defaultPreferences(String userId) {
    return NotificationPreferencesModel(
      userId: userId,
      allNotificationsEnabled: true,
      networkChanges: true,
      connectionState: true,
      poorSignal: true,
      significantLocation: true,
      roamingAlerts: true,
      dataUsageAlerts: true,
      securityAlerts: true,
      dataLimitGb: 10.0,
      currentDataUsedMb: 1250.0, // default baseline
    );
  }
}


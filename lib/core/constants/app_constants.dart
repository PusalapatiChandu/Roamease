class AppConstants {
  static const String appName = 'RoamEase';
  static const String appTagline = 'Smart Mobile Roaming & Location Management';

  // Firestore Collections
  static const String colSubscribers = 'subscribers';
  static const String colLocationHistory = 'location_history';
  static const String colNetworkHistory = 'network_history';
  static const String colUserSettings = 'user_settings';
  static const String colNotifications = 'notifications';

  // Mobile Network Operators
  static const List<String> popularOperators = [
    'Reliance Jio',
    'Bharti Airtel',
    'Vodafone Idea (Vi)',
    'BSNL',
    'Verizon Wireless',
    'AT&T Mobility',
    'T-Mobile US',
    'Vodafone UK',
    'EE',
    'O2',
    'Orange',
    'Deutsche Telekom',
    'Telstra',
    'Other Operator',
  ];

  // SIM Network Types
  static const List<String> simNetworkTypes = [
    '5G (NR Standalone / NSA)',
    '4G (LTE / LTE-A)',
  ];

  // Signal Strength Thresholds (dBm)
  static const int signalExcellentDbm = -80;
  static const int signalGoodDbm = -95;
  static const int signalFairDbm = -105;
  static const int signalPoorDbm = -115;

  // Speed Test endpoints (using ultra-fast reliable CDN test payload)
  static const String speedTestDownloadUrl = 'https://speed.cloudflare.com/__down?bytes=10000000'; // 10MB test payload
  static const String speedTestSmallDownloadUrl = 'https://speed.cloudflare.com/__down?bytes=2500000'; // 2.5MB payload
  static const String speedTestUploadUrl = 'https://speed.cloudflare.com/__up';
  static const String pingTargetHost = '8.8.8.8';

  // SharedPreferences Keys
  static const String prefIsDarkMode = 'roamease_dark_mode';
  static const String prefLocationTrackingActive = 'roamease_tracking_active';
  static const String prefNotificationsEnabled = 'roamease_notifications_enabled';
  static const String prefPoorSignalAlerts = 'roamease_poor_signal_alerts';
  static const String prefCachedUser = 'roamease_cached_subscriber';
  static const String prefLastLatitude = 'roamease_last_latitude';
  static const String prefLastLongitude = 'roamease_last_longitude';
  static const String prefNotificationPreferences = 'roamease_notification_prefs';
  static const String prefLocalNotificationsCache = 'roamease_notifications_cache';
  static const String prefOpenCellIdApiKey = 'roamease_opencellid_api_key';
}

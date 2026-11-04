import 'package:intl/intl.dart';

class Formatters {
  static String formatSpeed(double mbps) {
    if (mbps <= 0) return '0.00 Mbps';
    if (mbps < 1.0) {
      final kbps = mbps * 1024;
      return '${kbps.toStringAsFixed(0)} Kbps';
    }
    return '${mbps.toStringAsFixed(2)} Mbps';
  }

  static String formatDbm(int dbm) {
    if (dbm == -1 || dbm == 0) return 'N/A';
    return '$dbm dBm';
  }

  static String formatAsu(int asu) {
    if (asu == -1 || asu == 0) return 'N/A';
    return '$asu ASU';
  }

  static String formatCoordinates(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}° $latDir, ${lng.abs().toStringAsFixed(4)}° $lngDir';
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  static String formatTimeOnly(DateTime dateTime) {
    return DateFormat('hh:mm:ss a').format(dateTime);
  }

  static String formatDateOnly(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }
}

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  static Future<bool> checkLocationPermission() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  static Future<bool> requestPhonePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  static Future<bool> checkPhonePermission() async {
    if (!Platform.isAndroid) return true;
    return await Permission.phone.isGranted;
  }

  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<Map<String, bool>> checkAllKeyPermissions() async {
    final location = await Permission.locationWhenInUse.isGranted;
    final phone = Platform.isAndroid ? await Permission.phone.isGranted : true;
    final notification = await Permission.notification.isGranted;

    return {
      'location': location,
      'phone': phone,
      'notification': notification,
    };
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}

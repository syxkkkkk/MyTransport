import 'package:flutter/services.dart';

enum ArCoreStatus {
  /// Ready to use
  supportedInstalled,
  /// Device supports ARCore but needs installation from Play Store
  supportedNotInstalled,
  /// ARCore APK is outdated — needs update
  supportedApkTooOld,
  /// Hardware is not capable of ARCore
  unsupported,
  /// Unknown / error
  unknown,
}

/// Bridge to the native ARCore Geospatial Activity via MethodChannel.
class ArService {
  static const _channel =
      MethodChannel('com.mytransport.mytransport/ar_navigation');

  /// Returns the exact ARCore availability status for this device.
  static Future<ArCoreStatus> getArCoreStatus() async {
    try {
      final name = await _channel.invokeMethod<String>('isArCoreAvailable') ?? '';
      switch (name) {
        case 'SUPPORTED_INSTALLED':
          return ArCoreStatus.supportedInstalled;
        case 'SUPPORTED_NOT_INSTALLED':
          return ArCoreStatus.supportedNotInstalled;
        case 'SUPPORTED_APK_TOO_OLD':
          return ArCoreStatus.supportedApkTooOld;
        default:
          // UNSUPPORTED_DEVICE_NOT_CAPABLE, UNKNOWN_ERROR, etc.
          return ArCoreStatus.unsupported;
      }
    } on PlatformException {
      return ArCoreStatus.unknown;
    }
  }

  /// Launches the native ARCore Geospatial Activity full-screen.
  static Future<bool> launchARNavigation({
    required double latitude,
    required double longitude,
    required String stationName,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('launchARNavigation', {
        'latitude': latitude,
        'longitude': longitude,
        'stationName': stationName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('AR launch failed: ${e.message}');
    }
  }
}

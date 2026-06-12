import 'package:flutter/services.dart';

/// Bridge to the native ARCore Geospatial Activity via MethodChannel.
class ArService {
  static const _channel =
      MethodChannel('com.mytransport.mytransport/ar_navigation');

  /// Returns true if this device has ARCore installed and supported.
  static Future<bool> isArCoreAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isArCoreAvailable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Launches the native ARCore Geospatial Activity full-screen.
  /// [latitude] / [longitude] — destination coordinates.
  /// [stationName] — displayed in the AR HUD.
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

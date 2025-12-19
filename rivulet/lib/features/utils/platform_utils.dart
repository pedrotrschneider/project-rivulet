import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PlatformUtils {
  static bool _isTv = false;

  /// Returns the cached result.
  /// Make sure to call [init] in your main() before running the app.
  static bool get isTv => _isTv;

  static Future<void> init() async {
    if (kIsWeb) {
      _isTv = false;
      return;
    }

    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      final hasLeanback = androidInfo.systemFeatures.contains(
        'android.software.leanback',
      );
      final hasTouchScreen = androidInfo.systemFeatures.contains(
        'android.hardware.touchscreen',
      );

      _isTv = hasLeanback || !hasTouchScreen;
    } else {
      _isTv = false;
    }
  }
}

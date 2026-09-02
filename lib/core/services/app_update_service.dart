import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  /// Silently checks Google Play Store directly on Android for available updates.
  /// Safely ignored on Windows, Web, macOS, Linux, and iOS.
  static Future<void> checkForUpdates() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Start flexible update from Google Play Store
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      // Ignore ERROR_APP_NOT_OWNED in dev/debug mode when running from IDE/USB
      if (!e.toString().contains('ERROR_APP_NOT_OWNED') &&
          !e.toString().contains('-10')) {
        debugPrint('InAppUpdate Error: $e');
      }
    }
  }
}

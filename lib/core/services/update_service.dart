import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  static const String _configUrl =
      'https://raw.githubusercontent.com/OmarAfifi-CSE/tabattal/main/remote_config.json';

  /// Checks for an app update on Google Play.
  /// If an update is available, it fetches the remote_config.json from GitHub
  /// to determine if it should be a 'flexible' or 'immediate' update.
  /// It catches any exceptions (like no internet) silently.
  static Future<void> checkForUpdates() async {
    // In-app updates only work on Android.
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      // 1. Check if there is an update available on Google Play
      final info = await InAppUpdate.checkForUpdate();
      
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // 2. Fetch remote config to decide update type
        String updateType = 'flexible'; // default fallback
        
        try {
          final dio = Dio();
          // Timeout quickly so it doesn't hang the app if the network is poor
          dio.options.connectTimeout = const Duration(seconds: 3);
          dio.options.receiveTimeout = const Duration(seconds: 3);

          final response = await dio.get(_configUrl);
          
          if (response.statusCode == 200) {
            final data = response.data is String 
                ? jsonDecode(response.data) 
                : response.data;
                
            if (data['update_type'] != null) {
              updateType = data['update_type'].toString().toLowerCase();
            }
          }
        } catch (e) {
          // If fetching config fails (e.g., no internet or github is blocked),
          // we gracefully fallback to 'flexible' instead of crashing.
          debugPrint('Failed to fetch remote config: $e');
        }

        // 3. Trigger the appropriate update flow
        if (updateType == 'immediate') {
          await InAppUpdate.performImmediateUpdate();
        } else {
          await InAppUpdate.startFlexibleUpdate();
          // Complete the flexible update automatically once downloaded
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      // Catch any Play Store errors (e.g., no internet, or not installed via Play Store)
      debugPrint('Failed to check or perform in-app update: $e');
    }
  }
}

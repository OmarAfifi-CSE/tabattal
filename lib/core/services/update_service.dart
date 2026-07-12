import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  static const String _configUrl =
      'https://raw.githubusercontent.com/OmarAfifi-CSE/tabattal/main/remote_config.json';

  /// Checks for remote config and handles maintenance mode, announcements, and app updates.
  static Future<void> checkForUpdates(BuildContext context) async {
    // We only fetch config and check updates on mobile, not web.
    if (kIsWeb) return;

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 3);
      dio.options.receiveTimeout = const Duration(seconds: 3);

      final response = await dio.get(_configUrl);
      
      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        
        // 1. Check Maintenance Mode
        final isMaintenance = data['maintenance_mode'] == true;
        if (isMaintenance) {
          if (context.mounted) {
            _showMaintenanceDialog(context, data['maintenance_message']);
          }
          return; // Stop further execution if in maintenance
        }

        // 2. Check Announcements
        final showAnnouncement = data['show_announcement'] == true;
        if (showAnnouncement && context.mounted) {
          _showAnnouncementDialog(
            context, 
            data['announcement_title'], 
            data['announcement_message'], 
            data['announcement_url']
          );
        }

        // 3. Check App Updates (Android Only)
        if (Platform.isAndroid) {
          final updateType = data['update_type']?.toString().toLowerCase() ?? 'flexible';
          await _handleInAppUpdate(updateType);
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch remote config or update: $e');
      // Fallback: If network fails, still try to check Play Store for flexible update on Android
      if (!kIsWeb && Platform.isAndroid) {
        await _handleInAppUpdate('flexible');
      }
    }
  }

  static Future<void> _handleInAppUpdate(String type) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (type == 'immediate') {
          await InAppUpdate.performImmediateUpdate();
        } else {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('InAppUpdate Error: $e');
    }
  }

  static String _getLocalizedText(BuildContext context, dynamic textData) {
    if (textData is String) return textData;
    if (textData is Map) {
      final langCode = Localizations.localeOf(context).languageCode;
      return textData[langCode] ?? textData['en'] ?? textData['ar'] ?? '';
    }
    return '';
  }

  static void _showMaintenanceDialog(BuildContext context, dynamic messageData) {
    final message = _getLocalizedText(context, messageData);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // Prevent back button
        child: AlertDialog(
          title: const Icon(Icons.build_circle, color: Colors.orange, size: 50),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }

  static void _showAnnouncementDialog(BuildContext context, dynamic titleData, dynamic messageData, String? url) {
    final title = _getLocalizedText(context, titleData);
    final message = _getLocalizedText(context, messageData);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حسنًا'), // We can improve this with proper l10n later if needed
          ),
          // We can add a URL launcher button here later if `url` is provided
        ],
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import '../../../../l10n/app_localizations.dart';

/// Presentation-layer utility to resolve raw errors and exceptions
/// into high-quality, localized, user-friendly messages.
abstract final class VideoStudioErrorHelper {
  /// Converts any raw error or exception string into a user-facing localized message.
  static String getLocalizedError(BuildContext context, dynamic error) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null || error == null) {
      return l10n?.videoStudioProgressFailed ?? 'تعذر إعداد مقطع الفيديو';
    }

    final raw = error.toString().toLowerCase();

    // 1. File size exceeded / 413 / Large file error
    if (raw.contains('file_too_large') ||
        raw.contains('limit_file_size') ||
        raw.contains('413') ||
        raw.contains('يتجاوز الحد الأقصى') ||
        (raw.contains('حجم') && raw.contains('كبير'))) {
      return l10n.videoStudioFileTooLarge;
    }

    // 2. Timing authenticity unavailable for reciter
    if (raw.contains('توقيت حقيقية') ||
        raw.contains('reciterpath') ||
        raw.contains('timing unavailable') ||
        raw.contains('reciter timing') ||
        raw.contains('غير مدعوم')) {
      return l10n.videoStudioReciterTimingUnavailable;
    }

    // 3. Timing for specific verse error
    if (raw.contains('التوقيت الحقيقي الدقيق') ||
        raw.contains('word timing') ||
        raw.contains('segments') ||
        raw.contains('versekey')) {
      return l10n.videoStudioVerseTimingError;
    }

    // 4. Audio preparation cancelled
    if (raw.contains('cancelled') ||
        raw.contains('canceled') ||
        raw.contains('إلغاء')) {
      return l10n.videoStudioAudioCancelled;
    }

    // 5. Server connection / offline export microservice (Port 8080)
    if (raw.contains('8080') ||
        raw.contains('خادم تصدير الفيديو') ||
        raw.contains('video export service')) {
      return l10n.videoStudioExportServiceOffline;
    }

    // 6. Video encoding / rendering / FFmpeg / server processing failure
    if (raw.contains('ffmpeg') ||
        raw.contains('encoding') ||
        raw.contains('render') ||
        raw.contains('ترميز') ||
        raw.contains('معالجة الفيديو') ||
        raw.contains('server_error')) {
      final cleanMsg = error.toString().replaceAll('Exception:', '').trim();
      if (cleanMsg.isNotEmpty && cleanMsg.contains('معالجة') && !cleanMsg.contains('{')) {
        return cleanMsg;
      }
      return l10n.videoStudioRenderProcessingError;
    }

    // 7. Web browser canvas / MediaRecorder export failure
    if (raw.contains('mediarecorder') ||
        raw.contains('in this browser') ||
        raw.contains('متصفح') ||
        (raw.contains('canvas') && raw.contains('export'))) {
      return l10n.videoStudioWebExportError;
    }

    // 8. General Network / Internet connection errors for recitation/APIs
    if (raw.contains('socket') ||
        raw.contains('connection') ||
        raw.contains('timeout') ||
        raw.contains('host lookup') ||
        raw.contains('clientexception') ||
        raw.contains('handshake') ||
        raw.contains('net::err_') ||
        raw.contains('الإنترنت')) {
      return l10n.videoStudioNetworkError;
    }

    // 9. Audio download failure (404, not found, Dio bad response, network file download)
    if (raw.contains('تنزيل الملف الصوتي') ||
        raw.contains('download') ||
        raw.contains('audio file') ||
        raw.contains('404') ||
        raw.contains('not found') ||
        raw.contains('bad response') ||
        raw.contains('status code') ||
        raw.contains('dioexception')) {
      return l10n.videoStudioAudioDownloadError;
    }

    // 10. Audio duration measurement failure
    if (raw.contains('مدة') ||
        raw.contains('duration') ||
        raw.contains('قياس')) {
      return l10n.videoStudioAudioMeasureFailed;
    }

    // 11. Custom video URL & file validation errors
    if (raw.contains('invalid_url') || raw.contains('يبدأ بـ http')) {
      return l10n.videoStudioInvalidUrl;
    }
    if (raw.contains('download_failed') || raw.contains('فشل تحميل الفيديو من الرابط')) {
      return l10n.videoStudioDownloadUrlFailed;
    }
    if (raw.contains('empty_file') || raw.contains('فارغ أو غير صالح')) {
      return l10n.videoStudioEmptyFile;
    }

    // 12. If error is an Arabic/English human-readable string without technical stacktrace, return cleaned
    final cleanMsg = error.toString().replaceAll('Exception:', '').trim();
    if (cleanMsg.isNotEmpty &&
        !cleanMsg.contains('{') &&
        !cleanMsg.contains('stack trace') &&
        !cleanMsg.contains('dioexception') &&
        !cleanMsg.contains('at ') &&
        !cleanMsg.contains('line ')) {
      return cleanMsg;
    }

    return l10n.videoStudioProgressFailed;
  }
}

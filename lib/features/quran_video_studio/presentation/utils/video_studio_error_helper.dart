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

    // 1. Timing authenticity unavailable for reciter
    if (raw.contains('توقيت حقيقية') ||
        raw.contains('reciterpath') ||
        raw.contains('timing unavailable') ||
        raw.contains('reciter timing') ||
        raw.contains('غير مدعوم')) {
      return l10n.videoStudioReciterTimingUnavailable;
    }

    // 2. Timing for specific verse error
    if (raw.contains('التوقيت الحقيقي الدقيق') ||
        raw.contains('word timing') ||
        raw.contains('segments') ||
        raw.contains('versekey')) {
      return l10n.videoStudioVerseTimingError;
    }

    // 3. Audio preparation cancelled
    if (raw.contains('cancelled') ||
        raw.contains('canceled') ||
        raw.contains('إلغاء')) {
      return l10n.videoStudioAudioCancelled;
    }

    // 4. Audio download failure
    if (raw.contains('تنزيل الملف الصوتي') ||
        raw.contains('download') ||
        raw.contains('audio file')) {
      return l10n.videoStudioAudioDownloadError;
    }

    // 5. Audio duration measurement failure
    if (raw.contains('مدة') ||
        raw.contains('duration') ||
        raw.contains('قياس')) {
      return l10n.videoStudioAudioMeasureFailed;
    }

    // 6. Video encoding / rendering / FFmpeg failure
    if (raw.contains('ffmpeg') ||
        raw.contains('encoding') ||
        raw.contains('render') ||
        raw.contains('ترميز') ||
        raw.contains('معالجة')) {
      return l10n.videoStudioRenderProcessingError;
    }

    // 7. Web browser canvas / MediaRecorder export failure
    if (raw.contains('browser') ||
        raw.contains('web') ||
        raw.contains('canvas') ||
        raw.contains('متصفح')) {
      return l10n.videoStudioWebExportError;
    }

    // 8. General Network / Connection errors
    if (raw.contains('socket') ||
        raw.contains('connection') ||
        raw.contains('timeout') ||
        raw.contains('host lookup') ||
        raw.contains('clientexception') ||
        raw.contains('handshake') ||
        raw.contains('network') ||
        raw.contains('الإنترنت') ||
        raw.contains('الخادم')) {
      return l10n.videoStudioNetworkError;
    }

    // 9. If error is an Arabic/English human-readable string without technical stacktrace, return cleaned
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

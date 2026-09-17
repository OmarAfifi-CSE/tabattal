import 'package:flutter/widgets.dart';
import '../../../../l10n/app_localizations.dart';

/// Presentation-layer utility to resolve raw errors and exceptions
/// into high-quality, localized, user-friendly messages.
abstract final class VideoStudioErrorHelper {
  static final RegExp _ayahRegExp =
      RegExp(r'(?:للآية|آية|verse|ayah)\s*(\d+)', caseSensitive: false);

  /// Converts any raw error or exception string into a user-facing localized message.
  static String getLocalizedError(BuildContext context, dynamic error) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null || error == null) {
      return l10n?.videoStudioProgressFailed ?? 'تعذر إعداد مقطع الفيديو';
    }

    final raw = error.toString().toLowerCase();
    final isArabicLocale = Localizations.localeOf(context).languageCode == 'ar';

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
        raw.contains('غير مدعوم') ||
        raw.contains('خادم التوقيت') ||
        raw.contains('بيانات توقيت')) {
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

    // 5. Audio timeline incomplete
    if (raw.contains('قائمة مدد') ||
        (raw.contains('timeline') && raw.contains('incomplete')) ||
        raw.contains('durations list is incomplete')) {
      return l10n.videoStudioAudioTimelineIncomplete;
    }

    // 6. Audio duration measurement failure (Must precede general internet checks
    //    so specific measurement errors containing "الإنترنت" are not misclassified).
    if (raw.contains('قياس مدة') ||
        raw.contains('مدة المقطع') ||
        raw.contains('audio duration') ||
        (raw.contains('مدة') && raw.contains('قياس'))) {
      final match = _ayahRegExp.firstMatch(raw);
      final ayah = match != null ? int.tryParse(match.group(1) ?? '') : null;
      if (ayah != null) {
        return l10n.videoStudioMeasureDurationError(ayah);
      }
      return l10n.videoStudioAudioMeasureFailed;
    }

    // 7. Surah not downloaded locally on device
    if (raw.contains('غير محملة محليًا') ||
        raw.contains('غير محملة محليًّا') ||
        raw.contains('not downloaded locally') ||
        raw.contains('surah not downloaded')) {
      return l10n.videoStudioSurahNotDownloaded;
    }

    // 8. Specific audio file not found
    if (raw.contains('الملف الصوتي للآية') ||
        raw.contains('audio file for ayah') ||
        raw.contains('audio file for verse')) {
      final match = _ayahRegExp.firstMatch(raw);
      final ayah = match != null ? int.tryParse(match.group(1) ?? '') : null;
      if (ayah != null) {
        return l10n.videoStudioAudioFileNotFound(ayah);
      }
      return l10n.videoStudioAudioDownloadError;
    }

    // 9. Base card frame creation failure
    if (raw.contains('الإطار الأساسي') ||
        raw.contains('base card frame') ||
        raw.contains('create base frame')) {
      return l10n.videoStudioCreateBaseFrameError;
    }

    // 10. Verse text rendering failure
    if (raw.contains('رسم نصوص الآية') ||
        raw.contains('render text for verse')) {
      final match = _ayahRegExp.firstMatch(raw);
      final ayah = match != null ? int.tryParse(match.group(1) ?? '') : null;
      if (ayah != null) {
        return l10n.videoStudioRenderVerseTextError(ayah);
      }
      return l10n.videoStudioRenderProcessingError;
    }

    // 11. Final video file not found
    if (raw.contains('ملف الفيديو النهائي') ||
        raw.contains('final video file not found')) {
      return l10n.videoStudioVideoNotFound;
    }

    // 12. Custom background media not found
    if (raw.contains('فيديو الخلفية المخصص') ||
        raw.contains('الفيديو الخلفي المخصص') ||
        raw.contains('custom background video not found')) {
      return l10n.videoStudioCustomVideoNotFound;
    }
    if (raw.contains('صورة الخلفية المخصصة') ||
        raw.contains('الصورة الخلفية المخصصة') ||
        raw.contains('custom background image not found')) {
      return l10n.videoStudioCustomImageNotFound;
    }

    // 13. Server connection / offline export microservice (Port 8080)
    if (raw.contains('8080') ||
        raw.contains('خادم تصدير الفيديو') ||
        raw.contains('video export service')) {
      return l10n.videoStudioExportServiceOffline;
    }

    // 14. Video encoding / rendering / FFmpeg / server processing failure
    if (raw.contains('ffmpeg') ||
        raw.contains('encoding') ||
        raw.contains('render') ||
        raw.contains('ترميز') ||
        raw.contains('معالجة الفيديو') ||
        raw.contains('server_error')) {
      return l10n.videoStudioRenderProcessingError;
    }

    // 15. Web browser canvas / MediaRecorder export failure
    if (raw.contains('mediarecorder') ||
        raw.contains('in this browser') ||
        raw.contains('متصفح') ||
        (raw.contains('canvas') && raw.contains('export'))) {
      return l10n.videoStudioWebExportError;
    }

    // 16. Audio download failure (404, not found, Dio bad response, network file download)
    if (raw.contains('تنزيل الملف الصوتي') ||
        raw.contains('تحميل التلاوة') ||
        raw.contains('load recitation') ||
        raw.contains('download audio') ||
        raw.contains('audio file') ||
        raw.contains('404') ||
        raw.contains('bad response') ||
        raw.contains('status code')) {
      return l10n.videoStudioAudioDownloadError;
    }

    // 17. General Network / Internet connection errors for recitation/APIs
    if (raw.contains('socket') ||
        raw.contains('connection') ||
        raw.contains('timeout') ||
        raw.contains('host lookup') ||
        raw.contains('clientexception') ||
        raw.contains('handshake') ||
        raw.contains('net::err_') ||
        raw.contains('dioexception') ||
        raw.contains('الإنترنت')) {
      return l10n.videoStudioNetworkError;
    }

    // 18. General audio duration measurement (fallback)
    if (raw.contains('مدة') || raw.contains('duration')) {
      return l10n.videoStudioAudioMeasureFailed;
    }

    // 19. Custom video & image URL/file validation errors
    if (raw.contains('invalid_url') || raw.contains('يبدأ بـ http')) {
      return l10n.videoStudioInvalidUrl;
    }
    if (raw.contains('download_failed') ||
        raw.contains('فشل تحميل الفيديو من الرابط') ||
        raw.contains('فشل تحميل الصورة من الرابط')) {
      return l10n.videoStudioDownloadUrlFailed;
    }
    if (raw.contains('empty_file') ||
        raw.contains('فارغ أو غير صالح') ||
        raw.contains('الصورة المحملة فارغة')) {
      return l10n.videoStudioEmptyFile;
    }

    // 20. Human-readable language-safe fallback:
    // If the error message is clean and matches the user's active language, return it.
    // Otherwise, never leak foreign or technical strings to the user.
    final cleanMsg = error.toString().replaceAll('Exception:', '').trim();
    final hasArabicLetters = RegExp(r'[\u0600-\u06FF]').hasMatch(cleanMsg);
    final isTechnical = cleanMsg.contains('{') ||
        cleanMsg.contains('stack trace') ||
        cleanMsg.contains('dioexception') ||
        cleanMsg.contains('at ') ||
        cleanMsg.contains('line ') ||
        cleanMsg.contains('error:');

    if (cleanMsg.isNotEmpty && !isTechnical) {
      if (isArabicLocale && hasArabicLetters) {
        return cleanMsg;
      }
      if (!isArabicLocale && !hasArabicLetters) {
        return cleanMsg;
      }
    }

    return l10n.videoStudioProgressFailed;
  }
}

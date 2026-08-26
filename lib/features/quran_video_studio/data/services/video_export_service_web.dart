// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';
import '../../../../core/constants/quran_metadata.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/video_enums.dart';
import '../../domain/entities/video_project_config.dart';
import '../../domain/entities/video_render_progress.dart';
import '../../domain/entities/word_timing_segment.dart';
import '../../domain/repositories/i_video_export_service.dart';
import 'audio_timeline_service.dart';
import 'canvas_overlay_generator.dart';
import 'word_timing_service.dart';

class VideoExportService implements IVideoExportService {
  final CanvasOverlayGenerator _overlayGenerator;
  final AudioTimelineService _audioService;
  bool _isCancelled = false;
  html.HttpRequest? _activeRequest;

  static const String serverApiUrl = String.fromEnvironment(
    'VIDEO_EXPORT_API_URL',
    defaultValue: 'http://localhost:8080/api/export-video',
  );

  VideoExportService({
    CanvasOverlayGenerator? overlayGenerator,
    AudioTimelineService? audioService,
  })  : _overlayGenerator = overlayGenerator ?? const CanvasOverlayGenerator(),
        _audioService = audioService ?? AudioTimelineService();

  @override
  void cancel() {
    _isCancelled = true;
    _audioService.cancel();
    try {
      _activeRequest?.abort();
    } catch (_) {}
  }

  /// Coordinates video generation, frame rendering, cloud FFmpeg encoding, and MP4 download.
  @override
  Stream<VideoRenderProgress> exportVideo({
    required VideoProjectConfig config,
    required List<VerseModel> verses,
    required List<String> audioFilePaths,
    required List<Duration> verseDurations,
  }) {
    final controller = StreamController<VideoRenderProgress>();
    _isCancelled = false;

    () async {
      try {
        // Phase 1: Preparing timings and calculating layout (0% -> 10%)
        controller.add(const VideoRenderProgress(
          phase: VideoRenderPhase.downloadingAudio,
          progress: 0.05,
          statusMessage: 'جاري تجهيز بيانات الآيات والتلاوة...',
        ));

        if (_isCancelled) {
          controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled));
          await controller.close();
          return;
        }

        final isLineByLine = config.textDisplayMode == VideoTextDisplayMode.lineByLine;
        final wordTimingService = WordTimingService();
        final unitConfigs = <Map<String, dynamic>>[];

        for (int i = 0; i < verses.length; i++) {
          if (_isCancelled) {
            controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled));
            await controller.close();
            return;
          }

          final verse = verses[i];
          final pageNum = QuranMetadata.getPageNumberForAyah(config.surahNumber, verse.verseNumber);
          final totalDur = i < verseDurations.length && verseDurations[i].inMilliseconds > 500
              ? verseDurations[i]
              : const Duration(seconds: 4);

          final timings = await wordTimingService.getWordTimings(
            surahNumber: config.surahNumber,
            verse: verse,
            reciterPath: config.reciterPath,
            totalAyahDuration: totalDur,
          );

          if (isLineByLine && verse.words.isNotEmpty) {
            final lineSegments = WordTimingService.groupIntoLineSegments(
              verse: verse,
              wordTimings: timings,
              totalAyahDurationMs: totalDur.inMilliseconds,
            );
            for (int k = 0; k < lineSegments.length; k++) {
              final line = lineSegments[k];
              final startSec = line.startMs / 1000.0;
              final durSec = max((line.endMs - line.startMs) / 1000.0, 0.4);

              unitConfigs.add({
                'verse': verse,
                'verseIndex': i,
                'pageNum': pageNum,
                'timings': timings,
                'lineIndex': k,
                'startSec': startSec,
                'durSec': durSec,
                'verseNumber': verse.verseNumber,
                'lineCount': lineSegments.length,
                'currentLine': k + 1,
              });
            }
          } else {
            final durSec = totalDur.inMilliseconds / 1000.0;
            unitConfigs.add({
              'verse': verse,
              'verseIndex': i,
              'pageNum': pageNum,
              'timings': timings,
              'lineIndex': null,
              'startSec': 0.0,
              'durSec': durSec,
              'verseNumber': verse.verseNumber,
              'lineCount': 1,
              'currentLine': 1,
            });
          }
        }

        final totalUnits = unitConfigs.length;

        // Phase 2: Generating HD Base Frame and Transparent Overlays (10% -> 30%)
        final baseFrameBytes = await _overlayGenerator.generateStaticBaseFramePng(
          config: config,
          verse: verses.first,
          includeBackground: true,
        );

        if (baseFrameBytes == null) {
          throw Exception('فشل في إنشاء الإطار الأساسي للبطاقة');
        }

        final overlayBytesList = <Uint8List>[];

        for (int u = 0; u < totalUnits; u++) {
          if (_isCancelled) {
            controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled));
            await controller.close();
            return;
          }

          // Yield to UI event loop so ripple and CupertinoActivityIndicator animate at 120 FPS
          await Future<void>.delayed(Duration.zero);

          final unit = unitConfigs[u];
          final verse = unit['verse'] as VerseModel;
          final pageNum = unit['pageNum'] as int;
          final timings = unit['timings'] as List<WordTimingSegment>;
          final lineIndex = unit['lineIndex'] as int?;

          final overlayBytes = await _overlayGenerator.generateVerseOverlayPng(
            verse: verse,
            config: config,
            pageNumber: pageNum,
            translationText: verse.translation,
            tafsirText: verse.tafsir,
            wordTimings: timings,
            overrideLineIndex: lineIndex,
          );

          if (overlayBytes == null) {
            throw Exception('فشل في رسم نصوص الآية ${verse.verseNumber}');
          }

          overlayBytesList.add(overlayBytes);

          final overlayProgress = 0.10 + ((u + 1) / totalUnits) * 0.20;
          controller.add(VideoRenderProgress(
            phase: VideoRenderPhase.generatingOverlays,
            progress: overlayProgress.clamp(0.10, 0.30),
            statusMessage: isLineByLine
                ? 'جاري إعداد سطر (${unit['currentLine']}/${unit['lineCount']}) للآية (${verse.verseNumber})...'
                : 'جاري إعداد الآية (${verse.verseNumber})...',
          ));
        }

        // Phase 3: Uploading to Cloud FFmpeg Video Service (30% -> 95%)
        controller.add(const VideoRenderProgress(
          phase: VideoRenderPhase.encodingVideo,
          progress: -1.0,
          statusMessage: 'جاري إرسال البيانات ومعالجة الفيديو سحابيًا...',
        ));

        final formData = html.FormData();

        final metadataPayload = {
          'surahNumber': config.surahNumber,
          'startAyah': config.startAyah,
          'endAyah': config.endAyah,
          'reciterPath': config.reciterPath,
          'crf': config.videoQuality.crf,
          'unitConfigs': unitConfigs.map((u) => {
            'verseNumber': u['verseNumber'],
            'lineIndex': u['lineIndex'],
            'startSec': u['startSec'],
            'durSec': u['durSec'],
          }).toList(),
        };

        formData.append('metadata', jsonEncode(metadataPayload));
        formData.appendBlob('base_frame', html.Blob([baseFrameBytes], 'image/png'), 'base_frame.png');

        for (int u = 0; u < totalUnits; u++) {
          formData.appendBlob('overlay_unit_$u', html.Blob([overlayBytesList[u]], 'image/png'), 'overlay_unit_$u.png');
        }

        final requestCompleter = Completer<html.Blob>();
        final request = html.HttpRequest();
        _activeRequest = request;

        request.open('POST', serverApiUrl);
        request.responseType = 'blob';

        request.upload.onProgress.listen((html.ProgressEvent event) {
          if (event.lengthComputable && event.total != null && event.total! > 0) {
            final double uploadFraction = (event.loaded! / event.total!).clamp(0.0, 1.0);
            if (uploadFraction < 1.0) {
              controller.add(const VideoRenderProgress(
                phase: VideoRenderPhase.encodingVideo,
                progress: -1.0,
                statusMessage: 'جاري إرسال البيانات لخادم التصدير...',
              ));
            } else {
              controller.add(const VideoRenderProgress(
                phase: VideoRenderPhase.encodingVideo,
                progress: -1.0,
                statusMessage: 'جاري دمج الصوت ومعالجة مقطع الفيديو، يرجى الانتظار...',
              ));
            }
          }
        });

        request.onLoad.listen((event) async {
          if (request.status == 200) {
            final dynamic responseBlob = request.response;
            if (responseBlob is html.Blob) {
              requestCompleter.complete(responseBlob);
            } else {
              requestCompleter.completeError('Invalid response received from video export server.');
            }
          } else {
            String errorMsg = 'تعذر تصدير الفيديو على الخادم (${request.status})';
            try {
              final dynamic responseBlob = request.response;
              if (responseBlob is html.Blob) {
                final reader = html.FileReader();
                reader.readAsText(responseBlob);
                await reader.onLoad.first;
                final text = reader.result as String?;
                if (text != null && text.isNotEmpty) {
                  final json = jsonDecode(text) as Map<String, dynamic>;
                  errorMsg = (json['messageAr'] as String?) ??
                      (json['error'] as String?) ??
                      (json['messageEn'] as String?) ??
                      errorMsg;
                }
              }
            } catch (_) {}
            requestCompleter.completeError(errorMsg);
          }
        });

        request.onError.listen((event) {
          requestCompleter.completeError(
            'تعذر الاتصال بخادم تصدير الفيديو. يرجى التأكد من تشغيل خادم التصدير أو التحقق من الاتصال.',
          );
        });

        request.send(formData);

        controller.add(const VideoRenderProgress(
          phase: VideoRenderPhase.encodingVideo,
          progress: 0.75,
          statusMessage: 'جاري معالجة ودمج الصوت والفيديو عبر FFmpeg...',
        ));

        final mp4Blob = await requestCompleter.future;

        // Phase 4: Download MP4 file to client machine
        controller.add(const VideoRenderProgress(
          phase: VideoRenderPhase.encodingVideo,
          progress: 0.95,
          statusMessage: 'جاري تنزيل مقطع الـ MP4...',
        ));

        final surahName = QuranMetadata.getSurahName(config.surahNumber);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outputFileName = 'Tabattal_${surahName}_${config.startAyah}-${config.endAyah}_$timestamp.mp4';

        final downloadUrl = html.Url.createObjectUrlFromBlob(mp4Blob);
        final anchor = html.AnchorElement(href: downloadUrl)
          ..setAttribute('download', outputFileName)
          ..style.display = 'none';

        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(downloadUrl);

        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.completed,
          progress: 1.0,
          statusMessage: 'تم إنشاء وتنزيل مقطع الفيديو بنجاح!',
          outputPath: outputFileName,
        ));
      } catch (e) {
        final errorText = e is String
            ? e
            : (e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : e.toString());
        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.failed,
          progress: 0.0,
          statusMessage: errorText,
          errorMessage: errorText,
        ));
      } finally {
        _activeRequest = null;
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Web implementation for saving video (Downloaded directly to browser).
  static Future<bool> saveToGallery({
    required String filePath,
    String? album,
  }) async {
    return true;
  }

  /// Web implementation for sharing output.
  static Future<void> shareOutput({
    required String filePath,
    required String title,
  }) async {
    // Web downloads file directly via browser
  }
}


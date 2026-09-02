// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/video_enums.dart';
import '../../domain/entities/video_project_config.dart';
import '../../domain/entities/video_render_progress.dart';
import '../../domain/entities/word_timing_segment.dart';
import '../../domain/repositories/i_video_export_service.dart';
import '../../../../core/services/quran_font_service.dart';
import 'audio_timeline_service.dart';
import 'canvas_overlay_generator.dart';
import 'word_timing_service.dart';

class VideoExportService implements IVideoExportService {
  final CanvasOverlayGenerator _overlayGenerator;
  final AudioTimelineService _audioService;
  bool _isCancelled = false;
  html.HttpRequest? _activeRequest;
  String? _activeJobId;

  static html.Blob? _lastBlob;
  static Uint8List? _lastExportedBytes;
  static String? _lastExportedFileName;

  static const String serverApiUrl = String.fromEnvironment(
    'VIDEO_EXPORT_API_URL',
    defaultValue: 'http://localhost:8080/api/export-video',
  );

  VideoExportService({
    CanvasOverlayGenerator? overlayGenerator,
    AudioTimelineService? audioService,
  })  : _overlayGenerator = overlayGenerator ?? const CanvasOverlayGenerator(),
        _audioService = audioService ?? AudioTimelineService();

  StreamController<VideoRenderProgress>? _activeExportController;

  @override
  void cancel() {
    _isCancelled = true;
    _audioService.cancel();
    try {
      _activeRequest?.abort();
    } catch (_) {}
    if (_activeJobId != null) {
      try {
        final cancelUrl = serverApiUrl.replaceAll('/api/export-video', '/api/cancel-export/$_activeJobId');
        final cancelReq = html.HttpRequest();
        cancelReq.open('POST', cancelUrl);
        cancelReq.send();
      } catch (_) {}
      _activeJobId = null;
    }
    if (_activeExportController != null && !_activeExportController!.isClosed) {
      _activeExportController!.close();
    }
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
    _activeExportController = controller;
    _isCancelled = false;

    () async {
      try {
        // Phase 1: Preparing timings and calculating layout (0% -> 15%)
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

        final timingTasks = verses.map((verse) async {
          final i = verses.indexOf(verse);
          final pageNum = QuranMetadata.getPageNumberForAyah(config.surahNumber, verse.verseNumber);
          await QuranFontService.ensurePageFontLoaded(pageNum);
          final isEn = config.isEnglish;
          if (i >= verseDurations.length || verseDurations[i].inMilliseconds <= 500) {
            throw Exception(isEn
                ? 'Failed to measure exact audio duration for verse ${verse.verseNumber}'
                : 'تعذر تحديد المدة الصوتية الدقيقة للآية ${verse.verseNumber}');
          }
          final totalDur = verseDurations[i];

          final timings = await wordTimingService.getWordTimings(
            surahNumber: config.surahNumber,
            verse: verse,
            reciterPath: config.reciterPath,
            totalAyahDuration: totalDur,
          );

          return {
            'verse': verse,
            'verseIndex': i,
            'pageNum': pageNum,
            'timings': timings,
            'totalDur': totalDur,
          };
        }).toList();

        final timingResults = await Future.wait(timingTasks);
        final unitConfigs = <Map<String, dynamic>>[];

        for (final item in timingResults) {
          final verse = item['verse'] as VerseModel;
          final i = item['verseIndex'] as int;
          final pageNum = item['pageNum'] as int;
          final timings = item['timings'] as List<WordTimingSegment>;
          final totalDur = item['totalDur'] as Duration;

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
        final isEn = config.isEnglish;

        // Phase 2: Generating HD Base Frame and Ultra-Lightweight Transparent Overlays (15% -> 30%)
        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.generatingOverlays,
          step: VideoProgressStep.creatingBaseFrame,
          progress: 0.15,
          totalAyahsCount: verses.length,
        ));

        final hasCustomVideo = config.hasCustomVideo &&
            config.customVideoPath != null &&
            config.customVideoPath!.isNotEmpty;

        final rawBaseFrameBytes = await _overlayGenerator.generateStaticBaseFramePng(
          config: config,
          verse: verses.first,
          includeBackground: !hasCustomVideo,
        );

        if (rawBaseFrameBytes == null) {
          throw Exception(isEn ? 'Failed to create base card frame' : 'فشل في إنشاء الإطار الأساسي للبطاقة');
        }

        // When custom video is present, base_frame must remain PNG for transparent overlay.
        // Otherwise compress static base frame to high-quality JPEG (Quality 94%) to slash payload.
        final baseFrameBytes = hasCustomVideo
            ? rawBaseFrameBytes
            : await _compressToJpegWeb(rawBaseFrameBytes, quality: 0.94);
        final baseFrameExt = hasCustomVideo
            ? 'png'
            : (baseFrameBytes.length < rawBaseFrameBytes.length ? 'jpg' : 'png');
        final baseFrameMime = baseFrameExt == 'jpg' ? 'image/jpeg' : 'image/png';

        // Worker Pool with Concurrency Limiter (4 workers) to prevent GC thrashing
        final overlayBytesList = List<Uint8List?>.filled(totalUnits, null);
        const workerConcurrency = 4;
        int nextUnitIndex = 0;
        int completedOverlayUnits = 0;

        Future<void> overlayWorker() async {
          while (true) {
            if (_isCancelled) return;
            final u = nextUnitIndex++;
            if (u >= totalUnits) break;

            // Yield to UI loop
            await Future<void>.delayed(Duration.zero);

            final unit = unitConfigs[u];
            final verse = unit['verse'] as VerseModel;
            final verseIdx = (unit['verseIndex'] as int? ?? 0) + 1;
            final pageNum = unit['pageNum'] as int;
            final timings = unit['timings'] as List<WordTimingSegment>;
            final lineIndex = unit['lineIndex'] as int?;

            final overlayCrop = await _overlayGenerator.generateVerseOverlayCrop(
              verse: verse,
              config: config,
              pageNumber: pageNum,
              translationText: verse.translation,
              tafsirText: verse.tafsir,
              wordTimings: timings,
              overrideLineIndex: lineIndex,
            );

            if (overlayCrop == null) {
              throw Exception(isEn
                  ? 'Failed to render text for verse ${verse.verseNumber}'
                  : 'فشل في رسم نصوص الآية ${verse.verseNumber}');
            }

            overlayBytesList[u] = overlayCrop.bytes;
            unit['cropY'] = overlayCrop.cropY;
            unit['cropHeight'] = overlayCrop.cropHeight;

            completedOverlayUnits++;
            final overlayProgress = 0.15 + (completedOverlayUnits / totalUnits) * 0.15;
            controller.add(VideoRenderProgress(
              phase: VideoRenderPhase.generatingOverlays,
              step: isLineByLine ? VideoProgressStep.renderingLine : VideoProgressStep.renderingVerse,
              progress: overlayProgress.clamp(0.15, 0.30),
              ayahNumber: verse.verseNumber,
              currentAyahIndex: verseIdx,
              totalAyahsCount: verses.length,
              currentLine: isLineByLine ? (unit['currentLine'] as int) : 1,
              totalLines: isLineByLine ? (unit['lineCount'] as int) : 1,
            ));
          }
        }

        final workers = List.generate(
          min(workerConcurrency, totalUnits),
          (_) => overlayWorker(),
        );
        await Future.wait(workers);

        if (_isCancelled) {
          controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled, step: VideoProgressStep.cancelled));
          await controller.close();
          return;
        }

        // Phase 3: Uploading to Cloud FFmpeg Video Service (30% -> 50%)
        controller.add(const VideoRenderProgress(
          phase: VideoRenderPhase.encodingVideo,
          step: VideoProgressStep.uploadingPayload,
          progress: 0.30,
          uploadPercent: 0,
        ));

        final formData = html.FormData();
        final jobId = 'web_job_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
        _activeJobId = jobId;

        final metadataPayload = {
          'jobId': jobId,
          'surahNumber': config.surahNumber,
          'startAyah': config.startAyah,
          'endAyah': config.endAyah,
          'reciterPath': config.reciterPath,
          'crf': config.videoQuality.crf,
          'hasCustomVideo': hasCustomVideo,
          'backgroundDimming': config.backgroundDimming,
          'targetWidth': config.aspectRatio.getTargetWidth(config.videoQuality),
          'targetHeight': config.aspectRatio.getTargetHeight(config.videoQuality),
          'customVideoUrl': (hasCustomVideo &&
                  (config.customVideoPath!.startsWith('http://') ||
                      config.customVideoPath!.startsWith('https://')))
              ? config.customVideoPath!
              : null,
          'unitConfigs': unitConfigs.map((u) => {
            'verseNumber': u['verseNumber'],
            'lineIndex': u['lineIndex'],
            'startSec': u['startSec'],
            'durSec': u['durSec'],
            'cropY': u['cropY'] ?? 0,
            'cropHeight': u['cropHeight'] ?? 0,
          }).toList(),
        };

        formData.append('jobId', jobId);
        formData.append('metadata', jsonEncode(metadataPayload));
        formData.appendBlob('base_frame', html.Blob([baseFrameBytes], baseFrameMime), 'base_frame.$baseFrameExt');

        if (hasCustomVideo &&
            (config.customVideoPath!.startsWith('blob:') ||
                config.customVideoPath!.startsWith('data:'))) {
          final videoBlob = await _fetchBlobFromUrl(config.customVideoPath!);
          if (videoBlob != null) {
            formData.appendBlob('custom_video', videoBlob, 'custom_video.mp4');
          }
        }

        for (int u = 0; u < totalUnits; u++) {
          formData.appendBlob('overlay_unit_$u', html.Blob([overlayBytesList[u]], 'image/png'), 'overlay_unit_$u.png');
        }

        final requestCompleter = Completer<html.Blob>();
        final request = html.HttpRequest();
        _activeRequest = request;

        request.open('POST', serverApiUrl);
        request.responseType = 'blob';
        request.timeout = 300000; // 5 minutes timeout

        Timer? serverProgressPollTimer;
        bool serverPollingStarted = false;

        final double totalRecitationSec = unitConfigs.fold<double>(
          0.0,
          (sum, u) => sum + (u['durSec'] as double? ?? 4.0),
        );

        final progressUrl = serverApiUrl.replaceAll('/api/export-video', '/api/export-progress/$jobId');

        void startServerPolling() {
          if (serverPollingStarted) return;
          serverPollingStarted = true;
          serverProgressPollTimer?.cancel();

          controller.add(VideoRenderProgress(
            phase: VideoRenderPhase.encodingVideo,
            step: VideoProgressStep.serverEncoding,
            progress: 0.50,
            renderedSeconds: 0.0,
            totalSeconds: totalRecitationSec,
          ));

          // Poll live hardware FFmpeg progress from the server every 250ms
          serverProgressPollTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
            if (_isCancelled) {
              timer.cancel();
              return;
            }

            try {
              final pollReq = html.HttpRequest();
              pollReq.open('GET', progressUrl);
              pollReq.send();
              await pollReq.onLoad.first;
              if (pollReq.status == 200 && pollReq.responseText != null && pollReq.responseText!.isNotEmpty) {
                final data = jsonDecode(pollReq.responseText!) as Map<String, dynamic>;
                if (data['status'] == 'encoding') {
                  final renderedSec = (data['renderedSec'] as num?)?.toDouble() ?? 0.0;
                  final totalSec = (data['totalSec'] as num?)?.toDouble() ?? totalRecitationSec;
                  final speed = (data['speed'] as num?)?.toDouble();
                  final progress = (data['progress'] as num?)?.toDouble() ?? 0.50;

                  controller.add(VideoRenderProgress(
                    phase: VideoRenderPhase.encodingVideo,
                    step: VideoProgressStep.serverEncoding,
                    progress: progress.clamp(0.50, 0.99),
                    renderedSeconds: renderedSec,
                    totalSeconds: totalSec,
                    speed: speed,
                  ));
                }
              }
            } catch (_) {}
          });
        }

        request.upload.onProgress.listen((html.ProgressEvent event) {
          if (event.lengthComputable && event.total != null && event.total! > 0) {
            final double uploadFraction = (event.loaded! / event.total!).clamp(0.0, 1.0);
            final double uploadProgress = 0.30 + (uploadFraction * 0.20);
            final int percent = (uploadFraction * 100).toInt();

            if (uploadFraction < 1.0) {
              controller.add(VideoRenderProgress(
                phase: VideoRenderPhase.encodingVideo,
                step: VideoProgressStep.uploadingPayload,
                progress: uploadProgress.clamp(0.30, 0.50),
                uploadPercent: percent,
              ));
            } else {
              startServerPolling();
            }
          }
        });

        request.upload.onLoadEnd.listen((_) {
          startServerPolling();
        });

        request.onLoad.listen((event) async {
          serverProgressPollTimer?.cancel();
          if (request.status == 200) {
            final dynamic responseBlob = request.response;
            if (responseBlob is html.Blob) {
              controller.add(const VideoRenderProgress(
                phase: VideoRenderPhase.encodingVideo,
                step: VideoProgressStep.preparingDownload,
                progress: 0.99,
              ));
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
          serverProgressPollTimer?.cancel();
          requestCompleter.completeError(
            'تعذر الاتصال بخادم تصدير الفيديو. يرجى التأكد من تشغيل خادم التصدير أو التحقق من الاتصال.',
          );
        });

        request.onTimeout.listen((event) {
          serverProgressPollTimer?.cancel();
          requestCompleter.completeError(
            'استغرقت معالجة الفيديو وقتًا أطول من المتوقع على السيرفر. يرجى المحاولة مرة أخرى أو تقليل عدد الآيات.',
          );
        });

        request.send(formData);

        final mp4Blob = await requestCompleter.future;

        final surahName = QuranMetadata.getSurahName(config.surahNumber);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outputFileName = 'Tabattal_${surahName}_${config.startAyah}-${config.endAyah}_$timestamp.mp4';

        _lastBlob = mp4Blob;
        _lastExportedFileName = outputFileName;

        try {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(mp4Blob);
          await reader.onLoadEnd.first;
          final result = reader.result;
          if (result is Uint8List) {
            _lastExportedBytes = result;
          } else if (result is ByteBuffer) {
            _lastExportedBytes = result.asUint8List();
          } else if (result is List<int>) {
            _lastExportedBytes = Uint8List.fromList(result);
          }
        } catch (e) {
          debugPrint('Failed to convert video blob to bytes: $e');
        }

        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.completed,
          progress: 1.0,
          statusMessage: config.isEnglish ? 'Video created successfully!' : 'تم إنشاء مقطع الفيديو بنجاح!',
          outputPath: outputFileName,
        ));
      } catch (e) {
        if (_isCancelled) {
          return;
        }
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

  /// Saves the generated video file on Web by triggering direct browser download.
  static Future<bool?> saveVideo({
    required String filePath,
    required String suggestedName,
    String? album,
  }) async {
    try {
      if (_lastBlob != null) {
        final downloadName = suggestedName.isNotEmpty
            ? suggestedName
            : (_lastExportedFileName ?? filePath);
        final downloadUrl = html.Url.createObjectUrlFromBlob(_lastBlob!);
        final anchor = html.AnchorElement(href: downloadUrl)
          ..setAttribute('download', downloadName)
          ..style.display = 'none';

        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(downloadUrl);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Web saveVideo error: $e');
      return false;
    }
  }

  /// Web implementation for sharing output.
  static Future<void> shareOutput({
    required String filePath,
    String? title,
  }) async {
    final fileName = _lastExportedFileName ?? filePath;
    if (_lastExportedBytes != null) {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                _lastExportedBytes!,
                mimeType: 'video/mp4',
                name: fileName,
              ),
            ],
            title: title,
          ),
        );
      } catch (e) {
        debugPrint('Web share video error: $e');
        // Fallback to downloading if browser sharing fails
        await saveVideo(filePath: filePath, suggestedName: fileName);
      }
    } else if (_lastBlob != null) {
      await saveVideo(filePath: filePath, suggestedName: fileName);
    }
  }

  /// High-performance client-side PNG to JPEG converter using native browser canvas.
  static Future<Uint8List> _compressToJpegWeb(Uint8List pngBytes, {double quality = 0.94}) async {
    final blob = html.Blob([pngBytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      final img = html.ImageElement(src: url);
      await img.onLoad.first;
      final canvas = html.CanvasElement(width: img.naturalWidth, height: img.naturalHeight);
      final ctx = canvas.context2D;
      ctx.drawImage(img, 0, 0);
      final dataUrl = canvas.toDataUrl('image/jpeg', quality);
      final base64Str = dataUrl.split(',').last;
      return Uint8List.fromList(base64Decode(base64Str));
    } catch (_) {
      return pngBytes; // Fallback to raw bytes if conversion fails
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  /// Fetches an in-memory blob from a local object/blob URL.
  static Future<html.Blob?> _fetchBlobFromUrl(String blobUrl) async {
    final completer = Completer<html.Blob?>();
    try {
      final xhr = html.HttpRequest();
      xhr.open('GET', blobUrl);
      xhr.responseType = 'blob';
      xhr.onLoad.listen((_) {
        if (xhr.status == 200 || xhr.status == 0) {
          completer.complete(xhr.response as html.Blob?);
        } else {
          completer.complete(null);
        }
      });
      xhr.onError.listen((_) => completer.complete(null));
      xhr.send();
    } catch (_) {
      completer.complete(null);
    }
    return completer.future;
  }
}

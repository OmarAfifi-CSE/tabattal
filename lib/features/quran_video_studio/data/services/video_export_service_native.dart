import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  StreamController<VideoRenderProgress>? _activeExportController;

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
      FFmpegKit.cancel();
    } catch (_) {}
    if (_activeExportController != null && !_activeExportController!.isClosed) {
      _activeExportController!.close();
    }
  }

  /// Coordinates video generation, overlay frames, audio muxing, and MP4 video export.
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
        // Phase 1: Downloading & preparing audio (0% -> 10%)
        controller.add(const VideoRenderProgress(
          phase: VideoRenderPhase.downloadingAudio,
          progress: 0.05,
          statusMessage: 'جاري تجهيز المقاطع الصوتية...',
        ));

        if (_isCancelled) {
          controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled));
          await controller.close();
          return;
        }

        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final sessionDir = Directory('${tempDir.path}/video_session_$timestamp');
        if (!await sessionDir.exists()) {
          await sessionDir.create(recursive: true);
        }

        // Download / resolve any missing audio files in parallel
        final audioTasks = <Future<String?>>[];
        for (int i = 0; i < verses.length; i++) {
          final v = verses[i];
          final audioPath = i < audioFilePaths.length ? audioFilePaths[i] : null;

          if (audioPath != null && await File(audioPath).exists()) {
            audioTasks.add(Future.value(audioPath));
          } else {
            audioTasks.add(_audioService.getAyahAudioPath(
              surahNumber: config.surahNumber,
              ayahNumber: v.verseNumber,
              reciterPath: config.reciterPath,
            ));
          }
        }

        final resolvedAudioResults = await Future.wait(audioTasks);
        final resolvedAudioPaths = <String>[];
        for (final p in resolvedAudioResults) {
          if (p != null && p.isNotEmpty) {
            resolvedAudioPaths.add(p);
          }
        }

        if (_isCancelled) {
          controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled));
          await controller.close();
          return;
        }

        final isEn = config.isEnglish;
        final isLineByLine = config.textDisplayMode == VideoTextDisplayMode.lineByLine;
        final isCustomVideo = config.backgroundType == VideoBackgroundType.customVideo &&
            config.customVideoPath != null &&
            config.customVideoPath!.isNotEmpty &&
            File(config.customVideoPath!).existsSync();

        // Phase 2: Generating HD Base Frame and Transparent Overlays
        final baseFrameBytes = await _overlayGenerator.generateStaticBaseFramePng(
          config: config,
          verse: verses.first,
          includeBackground: !isCustomVideo,
        );
        if (baseFrameBytes == null) {
          throw Exception(config.isEnglish ? 'Failed to create base card frame' : 'فشل في إنشاء الإطار الأساسي للبطاقة');
        }
        final baseFrameFile = File('${sessionDir.path}/base_frame.png');
        await baseFrameFile.writeAsBytes(baseFrameBytes);
        final baseFramePath = baseFrameFile.path.replaceAll(r'\', '/');

        final surahName = QuranMetadata.getSurahName(config.surahNumber);
        final outputMp4File = File('${tempDir.path}/Tabattal_${surahName}_${config.startAyah}-${config.endAyah}_$timestamp.mp4');
        final outputPath = outputMp4File.path.replaceAll(r'\', '/');
        final quality = config.videoQuality;
        final crfArg = '-crf ${quality.crf}';
        final presetArg = isCustomVideo
            ? '-preset ultrafast -threads 0'
            : '-preset ultrafast -tune stillimage -threads 0';
        final targetW = config.aspectRatio.getTargetWidth(config.videoQuality);
        final targetH = config.aspectRatio.getTargetHeight(config.videoQuality);
        final bgVideoPath = isCustomVideo
            ? config.customVideoPath!.replaceAll(r'\', '/')
            : '';

        final wordTimingService = WordTimingService();
        int totalUnits = 0;

        // Calculate total rendering units (lines or verses) in parallel
        final timingTasks = verses.map((verse) async {
          final i = verses.indexOf(verse);
          final pageNum = QuranMetadata.getPageNumberForAyah(config.surahNumber, verse.verseNumber);
          final audioPath = i < resolvedAudioPaths.length ? resolvedAudioPaths[i].replaceAll(r'\', '/') : '';
          if (i >= verseDurations.length || verseDurations[i] == Duration.zero) {
            throw Exception(config.isEnglish
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
            'audioPath': audioPath,
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
          final audioPath = item['audioPath'] as String;
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
                'audioPath': audioPath,
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
              'audioPath': audioPath,
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

        totalUnits = unitConfigs.length;
        final totalDurationSec = unitConfigs.fold<double>(0.0, (sum, u) => sum + (u['durSec'] as double));

        // Phase 2: Generating HD Base Frame and Parallel Full-Frame Transparent Overlays (15% -> 30%)
        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.generatingOverlays,
          step: VideoProgressStep.creatingBaseFrame,
          progress: 0.15,
          totalAyahsCount: verses.length,
          statusMessage: 'جاري إنشاء الإطار الأساسي للبطاقة...',
        ));

        // Worker Pool with Concurrency Limiter (4 concurrent workers) for Ultra-Fast Micro-Cropped Overlays
        final overlayPaths = List<String>.filled(totalUnits, '');
        const workerConcurrency = 4;
        int nextUnitIndex = 0;
        int completedOverlayUnits = 0;

        Future<void> overlayWorker() async {
          while (true) {
            if (_isCancelled) return;
            final u = nextUnitIndex++;
            if (u >= totalUnits) break;

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

            unit['cropY'] = overlayCrop.cropY;
            unit['cropHeight'] = overlayCrop.cropHeight;

            final overlayFile = File('${sessionDir.path}/overlay_unit_$u.png');
            await overlayFile.writeAsBytes(overlayCrop.bytes);
            overlayPaths[u] = overlayFile.path.replaceAll(r'\', '/');

            completedOverlayUnits++;
            final overlayProgress = 0.05 + (completedOverlayUnits / totalUnits) * 0.15;
            controller.add(VideoRenderProgress(
              phase: VideoRenderPhase.generatingOverlays,
              step: isLineByLine ? VideoProgressStep.renderingLine : VideoProgressStep.renderingVerse,
              progress: overlayProgress.clamp(0.05, 0.20),
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

        // Phase 3: Ultra-Fast Segment Rendering & Instant Stream Copy Muxing (20% -> 99%)
        final validAudioFiles = <String>[];
        for (final p in resolvedAudioPaths) {
          if (p.isNotEmpty && await File(p).exists()) {
            validAudioFiles.add(p.replaceAll(r'\', '/'));
          }
        }

        final segmentPaths = <String>[];
        double completedRenderedSec = 0.0;
        double maxMonotonicRenderedSec = 0.0;
        double maxMonotonicProgress = 0.20;
        final encodingStopwatch = Stopwatch()..start();

        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.encodingVideo,
          step: VideoProgressStep.serverEncoding,
          progress: 0.20,
          ayahNumber: verses.first.verseNumber,
          currentAyahIndex: 1,
          totalAyahsCount: verses.length,
          renderedSeconds: 0.0,
          totalSeconds: totalDurationSec,
          speed: null,
        ));

        for (int u = 0; u < totalUnits; u++) {
          if (_isCancelled) {
            controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled, step: VideoProgressStep.cancelled));
            await controller.close();
            return;
          }

          final unit = unitConfigs[u];
          final durSec = unit['durSec'] as double;
          final cropY = unit['cropY'] as int? ?? 0;
          final segPath = '${sessionDir.path}/seg_$u.mp4';
          segmentPaths.add(segPath);

          final safeDurStr = durSec.toStringAsFixed(3);
          const fadeDur = 0.30;
          final safeFade = fadeDur.clamp(0.05, durSec * 0.20);
          final fadeOutStart = (durSec - safeFade).clamp(0.08, durSec);
          final fadeFilter = 'fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1';
          final String segCmd;

          if (isCustomVideo) {
            final segStart = completedRenderedSec.toStringAsFixed(3);
            final dimmingAlpha = config.backgroundDimming.clamp(0.0, 0.95).toStringAsFixed(2);
            segCmd = '-y -ss $segStart -t $safeDurStr -i "$bgVideoPath" -loop 1 -t $safeDurStr -framerate 30 -i "$baseFramePath" -loop 1 -t $safeDurStr -framerate 30 -i "${overlayPaths[u]}" -filter_complex "[2:v]$fadeFilter[ov];[0:v]setpts=PTS-STARTPTS,scale=$targetW:$targetH:force_original_aspect_ratio=increase,crop=$targetW:$targetH,setsar=1,format=yuv420p,drawbox=color=black@$dimmingAlpha:t=fill[bg];[bg][1:v]overlay=0:0[canvas];[canvas][ov]overlay=0:$cropY:format=auto[v]" -map "[v]" -t $safeDurStr -c:v libx264 $presetArg $crfArg -pix_fmt yuv420p -r 30 "$segPath"';
          } else {
            segCmd = '-y -loop 1 -t $safeDurStr -framerate 30 -i "$baseFramePath" -loop 1 -t $safeDurStr -framerate 30 -i "${overlayPaths[u]}" -filter_complex "[1:v]$fadeFilter[ov];[0:v][ov]overlay=0:$cropY:format=auto[v]" -map "[v]" -t $safeDurStr -c:v libx264 $presetArg $crfArg -pix_fmt yuv420p -r 30 "$segPath"';
          }

          final sessionCompleter = Completer<dynamic>();
          final baseCompletedSec = completedRenderedSec;

          await FFmpegKit.executeAsync(
            segCmd,
            (session) {
              if (!sessionCompleter.isCompleted) {
                sessionCompleter.complete(session);
              }
            },
            (log) {},
            (statistics) {
              if (_isCancelled) return;
              final currentSegRenderedMs = max(0, statistics.getTime());
              final currentSegRenderedSec = min(currentSegRenderedMs / 1000.0, durSec);
              final calculatedTotalSec = baseCompletedSec + currentSegRenderedSec;
              maxMonotonicRenderedSec = max(maxMonotonicRenderedSec, min(calculatedTotalSec, totalDurationSec));

              final ffmpegPercent = (maxMonotonicRenderedSec / totalDurationSec).clamp(0.0, 1.0);
              final calculatedProgress = 0.20 + (ffmpegPercent * 0.79);
              maxMonotonicProgress = max(maxMonotonicProgress, calculatedProgress.clamp(0.20, 0.99));

              final elapsedRealSec = encodingStopwatch.elapsedMilliseconds / 1000.0;
              final double? realMeasuredSpeed;
              if (elapsedRealSec >= 1.0 && maxMonotonicRenderedSec > 0.1) {
                realMeasuredSpeed = maxMonotonicRenderedSec / elapsedRealSec;
              } else {
                realMeasuredSpeed = null;
              }

              controller.add(VideoRenderProgress(
                phase: VideoRenderPhase.encodingVideo,
                step: VideoProgressStep.serverEncoding,
                progress: maxMonotonicProgress,
                ayahNumber: (unit['verse'] as VerseModel).verseNumber,
                currentAyahIndex: (unit['verseIndex'] as int? ?? 0) + 1,
                totalAyahsCount: verses.length,
                renderedSeconds: maxMonotonicRenderedSec,
                totalSeconds: totalDurationSec,
                speed: realMeasuredSpeed,
              ));
            },
          );

          final session = await sessionCompleter.future;
          if (_isCancelled) return;
          final returnCode = await session.getReturnCode();
          if (returnCode != null && ReturnCode.isCancel(returnCode)) {
            return;
          }
          if (returnCode == null || !ReturnCode.isSuccess(returnCode)) {
            if (_isCancelled) return;
            final logs = await session.getAllLogsAsString();
            throw Exception('تعذر رندر مقطع الفيديو $u: $logs');
          }

          completedRenderedSec += durSec;
          maxMonotonicRenderedSec = max(maxMonotonicRenderedSec, min(completedRenderedSec, totalDurationSec));

          final elapsedRealSec = encodingStopwatch.elapsedMilliseconds / 1000.0;
          final double? realMeasuredSpeed;
          if (elapsedRealSec >= 1.0 && maxMonotonicRenderedSec > 0.1) {
            realMeasuredSpeed = maxMonotonicRenderedSec / elapsedRealSec;
          } else {
            realMeasuredSpeed = null;
          }

          final ffmpegPercent = (completedRenderedSec / totalDurationSec).clamp(0.0, 1.0);
          final calculatedProgress = 0.20 + (ffmpegPercent * 0.79);
          maxMonotonicProgress = max(maxMonotonicProgress, calculatedProgress.clamp(0.20, 0.99));

          controller.add(VideoRenderProgress(
            phase: VideoRenderPhase.encodingVideo,
            step: VideoProgressStep.serverEncoding,
            progress: maxMonotonicProgress,
            ayahNumber: (unit['verse'] as VerseModel).verseNumber,
            currentAyahIndex: (unit['verseIndex'] as int? ?? 0) + 1,
            totalAyahsCount: verses.length,
            renderedSeconds: maxMonotonicRenderedSec,
            totalSeconds: totalDurationSec,
            speed: realMeasuredSpeed,
          ));
        }

        final rawVideoPath = '${sessionDir.path}/raw_video.mp4';
        if (segmentPaths.length == 1) {
          final copyCmd = '-y -i "${segmentPaths.first}" -c copy "$rawVideoPath"';
          await FFmpegKit.execute(copyCmd);
        } else {
          final concatListFile = File('${sessionDir.path}/segments.txt');
          final concatBuffer = StringBuffer();
          for (final p in segmentPaths) {
            concatBuffer.writeln("file '$p'");
          }
          await concatListFile.writeAsString(concatBuffer.toString());
          final concatInput = concatListFile.path.replaceAll(r'\', '/');

          final concatCmd = '-y -f concat -safe 0 -i "$concatInput" -c copy "$rawVideoPath"';
          final concatSession = await FFmpegKit.execute(concatCmd);
          final concatReturnCode = await concatSession.getReturnCode();
          if (!ReturnCode.isSuccess(concatReturnCode)) {
            final allLogs = await concatSession.getAllLogsAsString();
            throw Exception('تعذر تجميع مقاطع الفيديو: $allLogs');
          }
        }

        // Final Mux: Video Track + Audio Track with instant stream copy
        final hasAudio = validAudioFiles.isNotEmpty;
        final isCopySafeAudio = validAudioFiles.every((p) {
          final lower = p.toLowerCase();
          return lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.aac');
        });
        final audioCodecArg = isCopySafeAudio ? '-c:a copy' : '-c:a aac -b:a 128k';

        if (!hasAudio) {
          final copyCmd = '-y -i "$rawVideoPath" -c:v copy -movflags +faststart "$outputPath"';
          await FFmpegKit.execute(copyCmd);
        } else if (validAudioFiles.length == 1) {
          final singleAudio = validAudioFiles.first;
          final muxCmd = '-y -i "$rawVideoPath" -i "$singleAudio" -c:v copy $audioCodecArg -shortest -movflags +faststart "$outputPath"';
          final muxSession = await FFmpegKit.execute(muxCmd);
          final muxReturnCode = await muxSession.getReturnCode();
          if (!ReturnCode.isSuccess(muxReturnCode)) {
            final allLogs = await muxSession.getAllLogsAsString();
            throw Exception('تعذر دمج الصوت مع الفيديو: $allLogs');
          }
        } else {
          final audioConcatFile = File('${sessionDir.path}/audio_segments.txt');
          final audioBuffer = StringBuffer();
          for (final p in validAudioFiles) {
            audioBuffer.writeln("file '$p'");
          }
          await audioConcatFile.writeAsString(audioBuffer.toString());
          final audioConcatInput = audioConcatFile.path.replaceAll(r'\', '/');

          final muxCmd = '-y -i "$rawVideoPath" -f concat -safe 0 -i "$audioConcatInput" -c:v copy $audioCodecArg -shortest -movflags +faststart "$outputPath"';
          final muxSession = await FFmpegKit.execute(muxCmd);
          final muxReturnCode = await muxSession.getReturnCode();
          if (!ReturnCode.isSuccess(muxReturnCode)) {
            final allLogs = await muxSession.getAllLogsAsString();
            throw Exception('تعذر دمج الصوت مع الفيديو: $allLogs');
          }
        }

        if (!outputMp4File.existsSync() || outputMp4File.lengthSync() < 1024) {
          throw Exception(isEn ? 'Final video file not found' : 'تعذر العثور على ملف الفيديو النهائي');
        }

        String finalOutputPath = '';
        if (await outputMp4File.exists() && await outputMp4File.length() > 0) {
          finalOutputPath = outputMp4File.path;
        } else {
          throw Exception(isEn ? 'Final video file not found' : 'تعذر العثور على ملف الفيديو النهائي');
        }

        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.completed,
          progress: 1.0,
          statusMessage: isEn ? 'Video created successfully!' : 'تم إنشاء مقطع الفيديو بنجاح!',
          outputPath: finalOutputPath,
        ));
      } catch (e) {
        if (_isCancelled) {
          return;
        }
        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.failed,
          progress: 0.0,
          statusMessage: config.isEnglish ? 'An error occurred while exporting video' : 'حدث خطأ أثناء تصدير الفيديو',
          errorMessage: e.toString().replaceAll('Exception:', '').trim(),
        ));
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Saves the generated video file directly to device gallery via MediaStore (Zero permissions required).
  static Future<bool> saveToGallery({
    required String filePath,
    String? album,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists() || await file.length() == 0) {
        debugPrint('saveToGallery error: file not found or empty: $filePath');
        return false;
      }

      try {
        await Gal.putVideo(filePath, album: album);
        return true;
      } catch (albumError) {
        debugPrint('Gal with album error: $albumError, retrying without album');
        await Gal.putVideo(filePath);
        return true;
      }
    } catch (e) {
      debugPrint('Gal saveToGallery error: $e');
      return false;
    }
  }

  /// Shares the generated video file to social media or gallery.
  static Future<void> shareOutput({
    required String filePath,
    required String title,
  }) async {
    final file = File(filePath);
    if (await file.exists()) {
      final isVideo = filePath.toLowerCase().endsWith('.mp4');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: isVideo ? 'video/mp4' : 'image/png')],
          title: title,
        ),
      );
    }
  }
}

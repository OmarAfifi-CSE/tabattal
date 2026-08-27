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

        // Download / resolve any missing audio files
        final resolvedAudioPaths = <String>[];
        for (int i = 0; i < verses.length; i++) {
          if (_isCancelled) {
            controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled));
            await controller.close();
            return;
          }

          final v = verses[i];
          final audioPath = i < audioFilePaths.length ? audioFilePaths[i] : null;

          if (audioPath != null && await File(audioPath).exists()) {
            resolvedAudioPaths.add(audioPath);
          } else {
            final downloadedPath = await _audioService.getAyahAudioPath(
              surahNumber: config.surahNumber,
              ayahNumber: v.verseNumber,
              reciterPath: config.reciterPath,
            );
            if (downloadedPath != null) {
              resolvedAudioPaths.add(downloadedPath);
            }
          }
          final audioProgress = 0.05 + ((i + 1) / verses.length) * 0.05;
          controller.add(VideoRenderProgress(
            phase: VideoRenderPhase.downloadingAudio,
            step: VideoProgressStep.downloadingAudio,
            progress: audioProgress.clamp(0.05, 0.10),
            ayahNumber: v.verseNumber,
          ));
        }

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
          throw Exception('فشل في إنشاء الإطار الأساسي للبطاقة');
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

        final segmentPaths = <String>[];
        final wordTimingService = WordTimingService();
        int totalUnits = 0;

        // Calculate total rendering units (lines or verses)
        final unitConfigs = <Map<String, dynamic>>[];
        for (int i = 0; i < verses.length; i++) {
          final verse = verses[i];
          final pageNum = QuranMetadata.getPageNumberForAyah(config.surahNumber, verse.verseNumber);
          final audioPath = i < resolvedAudioPaths.length ? resolvedAudioPaths[i].replaceAll(r'\', '/') : '';
          final totalDur = i < verseDurations.length ? verseDurations[i] : const Duration(seconds: 4);

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
        final totalDurationMs = max(totalDurationSec * 1000.0, 1000.0);
        double completedDurationMs = 0.0;

        // Render each unit (Overlay -> Video Segment)
        for (int u = 0; u < totalUnits; u++) {
          if (_isCancelled) {
            controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled, step: VideoProgressStep.cancelled));
            await controller.close();
            return;
          }

          final unit = unitConfigs[u];
          final verse = unit['verse'] as VerseModel;
          final pageNum = unit['pageNum'] as int;
          final timings = unit['timings'] as List<WordTimingSegment>;
          final lineIndex = unit['lineIndex'] as int?;
          final durSec = unit['durSec'] as double;
          final unitDurationMs = durSec * 1000.0;

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

          final overlayFile = File('${sessionDir.path}/overlay_unit_$u.png');
          await overlayFile.writeAsBytes(overlayBytes);
          final overlayPath = overlayFile.path.replaceAll(r'\', '/');

          // Progress update for overlay generation (10% -> 20%)
          final overlayProgress = 0.10 + ((u + 1) / totalUnits) * 0.10;
          controller.add(VideoRenderProgress(
            phase: VideoRenderPhase.generatingOverlays,
            step: isLineByLine ? VideoProgressStep.renderingLine : VideoProgressStep.renderingVerse,
            progress: overlayProgress.clamp(0.10, 0.20),
            ayahNumber: verse.verseNumber,
            currentLine: isLineByLine ? (unit['currentLine'] as int) : 1,
            totalLines: isLineByLine ? (unit['lineCount'] as int) : 1,
          ));

          // Video encoding per segment
          final segmentFile = File('${sessionDir.path}/segment_$u.ts');
          final segmentPath = segmentFile.path.replaceAll(r'\', '/');
          segmentPaths.add(segmentPath);

          const fadeDur = 0.30;
          final safeFade = fadeDur.clamp(0.05, durSec * 0.20);
          final fadeOutStart = (durSec - safeFade).clamp(0.08, durSec);

          final String segmentCmd;
          if (isCustomVideo) {
            final startBgSec = (completedDurationMs / 1000.0).toStringAsFixed(3);
            final dimmingAlpha = config.backgroundDimming.clamp(0.0, 0.95).toStringAsFixed(2);
            segmentCmd = '-y -stream_loop -1 -ss $startBgSec -t $durSec -i "$bgVideoPath" '
                '-loop 1 -t $durSec -framerate 30 -i "$baseFramePath" '
                '-loop 1 -t $durSec -framerate 30 -i "$overlayPath" '
                '-filter_complex "[0:v]scale=$targetW:$targetH:force_original_aspect_ratio=increase,crop=$targetW:$targetH,setsar=1,format=yuv420p,drawbox=color=black@$dimmingAlpha:t=fill[bg_dim];'
                '[bg_dim][1:v]overlay=0:0[bg_dec];'
                '[2:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1[dyn];'
                '[bg_dec][dyn]overlay=0:0[v]" '
                '-map "[v]" -c:v libx264 $presetArg $crfArg -pix_fmt yuv420p -r 30 "$segmentPath"';
          } else {
            segmentCmd = '-y -loop 1 -t $durSec -framerate 30 -i "$baseFramePath" -loop 1 -t $durSec -framerate 30 -i "$overlayPath" '
                '-filter_complex "[1:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1[dyn];[0:v][dyn]overlay=0:0[v]" '
                '-map "[v]" -c:v libx264 $presetArg $crfArg -pix_fmt yuv420p -r 30 "$segmentPath"';
          }

          final sessionCompleter = Completer<dynamic>();
          final initialProgress = 0.20 + (completedDurationMs / totalDurationMs) * 0.74;
          controller.add(VideoRenderProgress(
            phase: VideoRenderPhase.encodingVideo,
            step: isLineByLine ? VideoProgressStep.renderingLine : VideoProgressStep.renderingVerse,
            progress: initialProgress.clamp(0.20, 0.94),
            ayahNumber: verse.verseNumber,
            currentLine: isLineByLine ? (unit['currentLine'] as int) : 1,
            totalLines: isLineByLine ? (unit['lineCount'] as int) : 1,
          ));

          await FFmpegKit.executeAsync(
            segmentCmd,
            (session) {
              if (!sessionCompleter.isCompleted) {
                sessionCompleter.complete(session);
              }
            },
            (log) {},
            (statistics) {
              if (_isCancelled) return;
              final currentUnitTimeMs = max(0, statistics.getTime());
              final totalRenderedMs = completedDurationMs + min(currentUnitTimeMs.toDouble(), unitDurationMs);
              final realProgress = (0.20 + (totalRenderedMs / totalDurationMs) * 0.74).clamp(0.20, 0.94);

              controller.add(VideoRenderProgress(
                phase: VideoRenderPhase.encodingVideo,
                step: isLineByLine ? VideoProgressStep.renderingLine : VideoProgressStep.renderingVerse,
                progress: realProgress,
                ayahNumber: verse.verseNumber,
                currentLine: isLineByLine ? (unit['currentLine'] as int) : 1,
                totalLines: isLineByLine ? (unit['lineCount'] as int) : 1,
              ));
            },
          );

          final completedSession = await sessionCompleter.future;
          final returnCode = await completedSession.getReturnCode();
          if (!ReturnCode.isSuccess(returnCode)) {
            final allLogs = await completedSession.getAllLogsAsString();
            throw Exception('تعذر إعداد مقطع الفيديو: $allLogs');
          }

          completedDurationMs += unitDurationMs;
        }

        // Concatenate all video segments and mux with 100% continuous audio stream
        controller.add(const VideoRenderProgress(
          phase: VideoRenderPhase.encodingVideo,
          step: VideoProgressStep.concatenatingSegments,
          progress: 0.95,
        ));

        final rawVideoFile = File('${sessionDir.path}/raw_video.mp4');
        final rawVideoPath = rawVideoFile.path.replaceAll(r'\', '/');

        if (segmentPaths.length == 1) {
          final singleSegment = File(segmentPaths.first);
          if (await singleSegment.exists()) {
            final copyCmd = '-y -i "${segmentPaths.first}" -c copy "$rawVideoPath"';
            await FFmpegKit.execute(copyCmd);
          }
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

        // Final Mux: Video Track + 100% Continuous Original Audio Stream (Zero AAC padding / Zero stutter)
        final validAudioFiles = <String>[];
        for (final p in resolvedAudioPaths) {
          if (p.isNotEmpty && await File(p).exists()) {
            validAudioFiles.add(p.replaceAll(r'\', '/'));
          }
        }

        if (validAudioFiles.isEmpty) {
          final copyCmd = '-y -i "$rawVideoPath" -c copy -movflags +faststart "$outputPath"';
          await FFmpegKit.execute(copyCmd);
        } else if (validAudioFiles.length == 1) {
          final singleAudio = validAudioFiles.first;
          final muxCmd = '-y -i "$rawVideoPath" -i "$singleAudio" -c:v copy -c:a aac -b:a 192k -movflags +faststart "$outputPath"';
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

          final muxCmd = '-y -i "$rawVideoPath" -f concat -safe 0 -i "$audioConcatInput" -c:v copy -c:a aac -b:a 192k -movflags +faststart "$outputPath"';
          final muxSession = await FFmpegKit.execute(muxCmd);
          final muxReturnCode = await muxSession.getReturnCode();
          if (!ReturnCode.isSuccess(muxReturnCode)) {
            final allLogs = await muxSession.getAllLogsAsString();
            throw Exception('تعذر دمج الصوت مع الفيديو: $allLogs');
          }
        }

        String finalOutputPath = '';
        if (await outputMp4File.exists() && await outputMp4File.length() > 0) {
          finalOutputPath = outputMp4File.path;
        } else {
          throw Exception('تعذر العثور على ملف الفيديو النهائي');
        }

        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.completed,
          progress: 1.0,
          statusMessage: 'تم إنشاء مقطع الفيديو بنجاح!',
          outputPath: finalOutputPath,
        ));
      } catch (e) {
        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.failed,
          progress: 0.0,
          statusMessage: 'حدث خطأ أثناء تصدير الفيديو',
          errorMessage: e.toString(),
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

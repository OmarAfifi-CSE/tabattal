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

        // Calculate total rendering units (lines or verses)
        final unitConfigs = <Map<String, dynamic>>[];
        for (int i = 0; i < verses.length; i++) {
          final verse = verses[i];
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
        final totalDurationMs = max(totalDurationSec * 1000.0, 1000.0);

        // Phase 2: Generating HD Base Frame and Ultra-Lightweight Cropped Overlays (15% -> 30%)
        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.generatingOverlays,
          step: VideoProgressStep.creatingBaseFrame,
          progress: 0.15,
          totalAyahsCount: verses.length,
          statusMessage: 'جاري إنشاء الإطار الأساسي للبطاقة...',
        ));

        final overlayPaths = <String>[];
        for (int u = 0; u < totalUnits; u++) {
          if (_isCancelled) {
            controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled, step: VideoProgressStep.cancelled));
            await controller.close();
            return;
          }

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
          overlayPaths.add(overlayFile.path.replaceAll(r'\', '/'));

          final overlayProgress = 0.15 + ((u + 1) / totalUnits) * 0.15;
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

        // Phase 3: Ultra-Fast Single-Pass FFmpeg Direct Mux Pipeline (30% -> 95%)
        final validAudioFiles = <String>[];
        for (final p in resolvedAudioPaths) {
          if (p.isNotEmpty && await File(p).exists()) {
            validAudioFiles.add(p.replaceAll(r'\', '/'));
          }
        }

        final inputArgs = StringBuffer();
        final filterBuffer = StringBuffer();

        if (isCustomVideo) {
          // Input 0: Background Video
          inputArgs.write('-stream_loop -1 -t ${totalDurationSec.toStringAsFixed(3)} -i "$bgVideoPath" ');
          // Input 1: Base Frame
          inputArgs.write('-loop 1 -t ${totalDurationSec.toStringAsFixed(3)} -framerate 25 -i "$baseFramePath" ');
          // Inputs 2 .. N+1: Overlay Frames
          for (int u = 0; u < totalUnits; u++) {
            final durSec = unitConfigs[u]['durSec'] as double;
            inputArgs.write('-loop 1 -t ${durSec.toStringAsFixed(3)} -framerate 25 -i "${overlayPaths[u]}" ');
          }

          final dimmingAlpha = config.backgroundDimming.clamp(0.0, 0.95).toStringAsFixed(2);
          filterBuffer.write('[0:v]setpts=PTS-STARTPTS,scale=$targetW:$targetH:force_original_aspect_ratio=increase,crop=$targetW:$targetH,setsar=1,format=yuv420p,drawbox=color=black@$dimmingAlpha:t=fill[bg];');
          filterBuffer.write('[bg][1:v]overlay=0:0[canvas0];');

          String currentCanvas = 'canvas0';
          double cumulativeStart = 0.0;

          for (int u = 0; u < totalUnits; u++) {
            final durSec = unitConfigs[u]['durSec'] as double;
            final cropY = unitConfigs[u]['cropY'] as int? ?? 0;
            final segStart = cumulativeStart;
            final segEnd = segStart + durSec;
            cumulativeStart += durSec;

            const fadeDur = 0.30;
            final safeFade = fadeDur.clamp(0.05, durSec * 0.20);
            final fadeOutStart = (durSec - safeFade).clamp(0.08, durSec);
            final nextCanvas = (u == totalUnits - 1) ? 'v' : 'canvas${u + 1}';

            filterBuffer.write('[${u + 2}:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${segStart.toStringAsFixed(3)}/TB[ov$u];');
            filterBuffer.write('[$currentCanvas][ov$u]overlay=0:$cropY:enable=\'between(t,${segStart.toStringAsFixed(3)},${segEnd.toStringAsFixed(3)})\'[$nextCanvas];');
            currentCanvas = nextCanvas;
          }
        } else {
          // Input 0: Base Frame
          inputArgs.write('-loop 1 -t ${totalDurationSec.toStringAsFixed(3)} -framerate 25 -i "$baseFramePath" ');
          // Inputs 1 .. N: Overlay Frames
          for (int u = 0; u < totalUnits; u++) {
            final durSec = unitConfigs[u]['durSec'] as double;
            inputArgs.write('-loop 1 -t ${durSec.toStringAsFixed(3)} -framerate 25 -i "${overlayPaths[u]}" ');
          }

          String currentCanvas = '0:v';
          double cumulativeStart = 0.0;

          for (int u = 0; u < totalUnits; u++) {
            final durSec = unitConfigs[u]['durSec'] as double;
            final cropY = unitConfigs[u]['cropY'] as int? ?? 0;
            final segStart = cumulativeStart;
            final segEnd = segStart + durSec;
            cumulativeStart += durSec;

            const fadeDur = 0.30;
            final safeFade = fadeDur.clamp(0.05, durSec * 0.20);
            final fadeOutStart = (durSec - safeFade).clamp(0.08, durSec);
            final nextCanvas = (u == totalUnits - 1) ? 'v' : 'canvas${u + 1}';

            filterBuffer.write('[${u + 1}:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${segStart.toStringAsFixed(3)}/TB[ov$u];');
            filterBuffer.write('[$currentCanvas][ov$u]overlay=0:$cropY:enable=\'between(t,${segStart.toStringAsFixed(3)},${segEnd.toStringAsFixed(3)})\'[$nextCanvas];');
            currentCanvas = nextCanvas;
          }
        }

        // Add Audio Input directly into the same single-pass command
        final hasAudio = validAudioFiles.isNotEmpty;
        final audioInputIndex = isCustomVideo ? totalUnits + 2 : totalUnits + 1;
        if (hasAudio) {
          if (validAudioFiles.length == 1) {
            inputArgs.write('-i "${validAudioFiles.first}" ');
          } else {
            final audioConcatFile = File('${sessionDir.path}/audio_segments.txt');
            final audioBuffer = StringBuffer();
            for (final p in validAudioFiles) {
              audioBuffer.writeln("file '$p'");
            }
            await audioConcatFile.writeAsString(audioBuffer.toString());
            final audioConcatInput = audioConcatFile.path.replaceAll(r'\', '/');
            inputArgs.write('-f concat -safe 0 -i "$audioConcatInput" ');
          }
        }

        final isCopySafeAudio = validAudioFiles.every((p) {
          final lower = p.toLowerCase();
          return lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.aac');
        });
        final audioCodecArg = isCopySafeAudio ? '-c:a copy' : '-c:a aac -b:a 128k';
        final audioMapArg = hasAudio ? '-map $audioInputIndex:a $audioCodecArg -shortest' : '';
        const x264Opts = '-x264opts no-mbtree=1:rc-lookahead=0:sync-lookahead=0:subme=0:me=dia:ref=1';

        // Hardware-accelerated encoding for iOS VideoToolbox / Multithreaded ultrafast for Android
        final String videoEncoderArgs;
        if (!kIsWeb && Platform.isIOS) {
          videoEncoderArgs = '-c:v h264_videotoolbox -b:v 3500k';
        } else {
          videoEncoderArgs = '-c:v libx264 $presetArg $crfArg $x264Opts';
        }

        final singlePassCmd = '-y ${inputArgs.toString()} -filter_complex "${filterBuffer.toString()}" -map "[v]" $audioMapArg -t ${totalDurationSec.toStringAsFixed(3)} $videoEncoderArgs -pix_fmt yuv420p -r 25 -movflags +faststart "$outputPath"';

        final sessionCompleter = Completer<dynamic>();
        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.encodingVideo,
          step: VideoProgressStep.serverEncoding,
          progress: 0.25,
          ayahNumber: verses.first.verseNumber,
          totalAyahsCount: verses.length,
          renderedSeconds: 0.0,
          totalSeconds: totalDurationSec,
        ));

        await FFmpegKit.executeAsync(
          singlePassCmd,
          (session) {
            if (!sessionCompleter.isCompleted) {
              sessionCompleter.complete(session);
            }
          },
          (log) {},
          (statistics) {
            if (_isCancelled) return;
            final currentRenderedMs = max(0, statistics.getTime());
            final currentRenderedSec = min(currentRenderedMs / 1000.0, totalDurationSec);
            final ffmpegPercent = (currentRenderedMs / totalDurationMs).clamp(0.0, 1.0);
            final realProgress = (0.25 + ffmpegPercent * 0.73).clamp(0.25, 0.98);

            final speed = statistics.getSpeed();
            controller.add(VideoRenderProgress(
              phase: VideoRenderPhase.encodingVideo,
              step: VideoProgressStep.serverEncoding,
              progress: realProgress,
              ayahNumber: verses.first.verseNumber,
              totalAyahsCount: verses.length,
              renderedSeconds: currentRenderedSec,
              totalSeconds: totalDurationSec,
              speed: speed > 0 ? speed : null,
            ));
          },
        );

        final completedSession = await sessionCompleter.future;
        final returnCode = await completedSession.getReturnCode();

        if (returnCode == null || !ReturnCode.isSuccess(returnCode)) {
          final logs = await completedSession.getAllLogsAsString();
          final allLogs = logs ?? 'Unknown FFmpeg error';
          final failMsg = isEn ? 'Failed to process video: $allLogs' : 'تعذر إعداد مقطع الفيديو: $allLogs';
          throw Exception(failMsg);
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

import 'dart:async';
import 'dart:io';
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
import 'audio_timeline_service.dart';
import 'canvas_overlay_generator.dart';

class VideoExportService {
  final CanvasOverlayGenerator _overlayGenerator;
  final AudioTimelineService _audioService;
  bool _isCancelled = false;

  VideoExportService({
    CanvasOverlayGenerator? overlayGenerator,
    AudioTimelineService? audioService,
  })  : _overlayGenerator = overlayGenerator ?? const CanvasOverlayGenerator(),
        _audioService = audioService ?? AudioTimelineService();

  void cancel() {
    _isCancelled = true;
    _audioService.cancel();
    try {
      FFmpegKit.cancel();
    } catch (_) {}
  }

  /// Coordinates video generation, overlay frames, audio muxing, and MP4 video export.
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
            progress: audioProgress.clamp(0.05, 0.10),
            statusMessage: 'جاري تجهيز تلاوة الآية (${v.verseNumber})...',
          ));
        }

        // Phase 2: Generating HD Base Frame and Transparent Overlays for Each Verse (10% -> 40%)
        final baseFrameBytes = await _overlayGenerator.generateStaticBaseFramePng(
          config: config,
          verse: verses.first,
        );
        if (baseFrameBytes == null) {
          throw Exception('فشل في إنشاء الإطار الأساسي للبطاقة');
        }
        final baseFrameFile = File('${sessionDir.path}/base_frame.png');
        await baseFrameFile.writeAsBytes(baseFrameBytes);
        final baseFramePath = baseFrameFile.path.replaceAll(r'\', '/');

        final overlayPaths = <String>[];
        for (int i = 0; i < verses.length; i++) {
          if (_isCancelled) {
            controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled));
            await controller.close();
            return;
          }

          final verse = verses[i];
          final pageNum = QuranMetadata.getPageNumberForAyah(config.surahNumber, verse.verseNumber);

          final overlayBytes = await _overlayGenerator.generateVerseOverlayPng(
            verse: verse,
            config: config,
            pageNumber: pageNum,
            translationText: verse.translation,
            tafsirText: verse.tafsir,
          );

          if (overlayBytes == null) {
            throw Exception('فشل في رسم الآية ${verse.verseNumber}');
          }

          final overlayFile = File('${sessionDir.path}/overlay_$i.png');
          await overlayFile.writeAsBytes(overlayBytes);
          overlayPaths.add(overlayFile.path.replaceAll(r'\', '/'));

          final overlayProgress = 0.10 + ((i + 1) / verses.length) * 0.30;
          controller.add(VideoRenderProgress(
            phase: VideoRenderPhase.generatingOverlays,
            progress: overlayProgress.clamp(0.10, 0.40),
            statusMessage: 'جاري إعداد الآية (${verse.verseNumber})...',
          ));
        }

        // Phase 3: High-FPS Hardware Accelerated Video Encoding (40% -> 98%)
        final surahName = QuranMetadata.getSurahName(config.surahNumber);
        final outputMp4File = File('${tempDir.path}/Tabattal_${surahName}_${config.startAyah}-${config.endAyah}_$timestamp.mp4');
        final outputPath = outputMp4File.path.replaceAll(r'\', '/');
        final quality = config.videoQuality;
        final crfArg = '-crf ${quality.crf}';
        const presetArg = '-preset fast';

        if (verses.length == 1) {
          final d = verseDurations.isNotEmpty ? (verseDurations[0].inMilliseconds / 1000.0) : 4.0;
          final audioPath = resolvedAudioPaths.isNotEmpty ? resolvedAudioPaths[0].replaceAll(r'\', '/') : '';
          final hasAudio = audioPath.isNotEmpty && await File(audioPath).exists();

          const fadeDur = 0.45;
          final safeFade = fadeDur.clamp(0.08, d * 0.20);
          final fadeOutStart = (d - safeFade).clamp(0.10, d);

          String ffmpegCmd;
          if (hasAudio) {
            ffmpegCmd = '-y -loop 1 -t $d -framerate 30 -i "$baseFramePath" -loop 1 -t $d -framerate 30 -i "${overlayPaths[0]}" -i "$audioPath" '
                '-filter_complex "[1:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1[dyn];[0:v][dyn]overlay=0:0[v]" '
                '-map "[v]" -map 2:a -c:v libx264 $presetArg $crfArg -pix_fmt yuv420p -r 30 -c:a aac -b:a 192k -shortest "$outputPath"';
          } else {
            ffmpegCmd = '-y -loop 1 -t $d -framerate 30 -i "$baseFramePath" -loop 1 -t $d -framerate 30 -i "${overlayPaths[0]}" '
                '-filter_complex "[1:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1[dyn];[0:v][dyn]overlay=0:0[v]" '
                '-map "[v]" -c:v libx264 $presetArg $crfArg -pix_fmt yuv420p -r 30 "$outputPath"';
          }

          controller.add(const VideoRenderProgress(
            phase: VideoRenderPhase.encodingVideo,
            progress: 0.50,
            statusMessage: 'جاري معالجة المقطع القرآني...',
          ));

          final session = await FFmpegKit.execute(ffmpegCmd);
          final returnCode = await session.getReturnCode();
          if (!ReturnCode.isSuccess(returnCode)) {
            final allLogs = await session.getAllLogsAsString();
            throw Exception('تعذر إعداد مقطع الفيديو: $allLogs');
          }
        } else {
          // Multi-verse project: render high-quality 30 FPS segment per verse, then concatenate losslessly
          final segmentPaths = <String>[];

          for (int i = 0; i < verses.length; i++) {
            if (_isCancelled) {
              controller.add(const VideoRenderProgress(phase: VideoRenderPhase.cancelled));
              await controller.close();
              return;
            }

            final d = i < verseDurations.length ? (verseDurations[i].inMilliseconds / 1000.0) : 4.0;
            final audioPath = i < resolvedAudioPaths.length ? resolvedAudioPaths[i].replaceAll(r'\', '/') : '';
            final hasAudio = audioPath.isNotEmpty && await File(audioPath).exists();

            const fadeDur = 0.45;
            final safeFade = fadeDur.clamp(0.08, d * 0.20);
            final fadeOutStart = (d - safeFade).clamp(0.10, d);

            final segmentFile = File('${sessionDir.path}/segment_$i.ts');
            final segmentPath = segmentFile.path.replaceAll(r'\', '/');
            segmentPaths.add(segmentPath);

            String segmentCmd;
            if (hasAudio) {
              segmentCmd = '-y -loop 1 -t $d -framerate 30 -i "$baseFramePath" -loop 1 -t $d -framerate 30 -i "${overlayPaths[i]}" -i "$audioPath" '
                  '-filter_complex "[1:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1[dyn];[0:v][dyn]overlay=0:0[v]" '
                  '-map "[v]" -map 2:a -c:v libx264 $presetArg $crfArg -pix_fmt yuv420p -r 30 -c:a aac -b:a 192k -shortest "$segmentPath"';
            } else {
              segmentCmd = '-y -loop 1 -t $d -framerate 30 -i "$baseFramePath" -loop 1 -t $d -framerate 30 -i "${overlayPaths[i]}" '
                  '-filter_complex "[1:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1[dyn];[0:v][dyn]overlay=0:0[v]" '
                  '-map "[v]" -c:v libx264 $presetArg $crfArg -pix_fmt yuv420p -r 30 "$segmentPath"';
            }

            final progressVal = 0.40 + ((i + 1) / verses.length) * 0.52;
            controller.add(VideoRenderProgress(
              phase: VideoRenderPhase.encodingVideo,
              progress: progressVal.clamp(0.40, 0.95),
              statusMessage: 'جاري معالجة الآية (${verses[i].verseNumber})...',
            ));

            final session = await FFmpegKit.execute(segmentCmd);
            final returnCode = await session.getReturnCode();
            if (!ReturnCode.isSuccess(returnCode)) {
              final allLogs = await session.getAllLogsAsString();
              throw Exception('تعذر إعداد الآية ${verses[i].verseNumber}: $allLogs');
            }
          }

          // Concatenate all high-fps segments
          controller.add(const VideoRenderProgress(
            phase: VideoRenderPhase.encodingVideo,
            progress: 0.95,
            statusMessage: 'جاري إتمام وحفظ الفيديو النهائي...',
          ));

          final concatListFile = File('${sessionDir.path}/segments.txt');
          final concatBuffer = StringBuffer();
          for (final p in segmentPaths) {
            concatBuffer.writeln("file '$p'");
          }
          await concatListFile.writeAsString(concatBuffer.toString());
          final concatInput = concatListFile.path.replaceAll(r'\', '/');

          final concatCmd = '-y -f concat -safe 0 -i "$concatInput" -c copy -movflags +faststart "$outputPath"';
          final concatSession = await FFmpegKit.execute(concatCmd);
          final concatReturnCode = await concatSession.getReturnCode();
          if (!ReturnCode.isSuccess(concatReturnCode)) {
            final allLogs = await concatSession.getAllLogsAsString();
            throw Exception('تعذر تجميع مقاطع الآيات: $allLogs');
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
    if (kIsWeb) return false;
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
    if (kIsWeb) return;
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

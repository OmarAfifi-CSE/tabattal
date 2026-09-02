import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

        final renderOutputFile = File('${sessionDir.path}/render_output.mp4');
        final renderOutputPath = renderOutputFile.path.replaceAll(r'\', '/');
        final targetW = config.aspectRatio.getTargetWidth(config.videoQuality);
        final targetH = config.aspectRatio.getTargetHeight(config.videoQuality);

        String bgVideoPath = '';
        if (isCustomVideo) {
          final rawBgPath = config.customVideoPath!;
          final hasSpecialChars = rawBgPath.codeUnits.any((c) => c > 127) ||
              rawBgPath.contains(' ') ||
              rawBgPath.contains("'");
          if (hasSpecialChars) {
            final safeBgFile = File('${sessionDir.path}/custom_bg.mp4');
            try {
              await File(rawBgPath).copy(safeBgFile.path);
              bgVideoPath = safeBgFile.path.replaceAll(r'\', '/');
            } catch (e) {
              debugPrint('Failed to copy custom video to safe ASCII path: $e');
              bgVideoPath = rawBgPath.replaceAll(r'\', '/');
            }
          } else {
            bgVideoPath = rawBgPath.replaceAll(r'\', '/');
          }
        }

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

        // Dynamic Worker Pool scaled to hardware capabilities (up to 16 parallel workers on modern desktop CPUs)
        final overlayPaths = List<String>.filled(totalUnits, '');
        final workerConcurrency = Platform.numberOfProcessors.clamp(4, 16);
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
        for (int i = 0; i < resolvedAudioPaths.length; i++) {
          final p = resolvedAudioPaths[i];
          if (p.isNotEmpty && await File(p).exists()) {
            final hasSpecialChars = p.codeUnits.any((c) => c > 127) ||
                p.contains(' ') ||
                p.contains("'");
            if (hasSpecialChars) {
              final ext = p.contains('.') ? p.substring(p.lastIndexOf('.')) : '.mp3';
              final safeAudioFile = File('${sessionDir.path}/audio_$i$ext');
              try {
                await File(p).copy(safeAudioFile.path);
                validAudioFiles.add(safeAudioFile.path.replaceAll(r'\', '/'));
              } catch (_) {
                validAudioFiles.add(p.replaceAll(r'\', '/'));
              }
            } else {
              validAudioFiles.add(p.replaceAll(r'\', '/'));
            }
          }
        }

        final filterChains = <String>[];
        final ffmpegArgs = <String>[
          '-y',
          '-threads', '0',
          '-filter_complex_threads', '0',
        ];
        final totalDurationStr = totalDurationSec.toStringAsFixed(3);

        if (isCustomVideo) {
          ffmpegArgs.addAll(['-stream_loop', '-1', '-i', bgVideoPath]);
          ffmpegArgs.addAll(['-loop', '1', '-t', totalDurationStr, '-framerate', '30', '-i', baseFramePath]);

          for (int u = 0; u < totalUnits; u++) {
            final durSec = (unitConfigs[u]['durSec'] as double).toStringAsFixed(3);
            ffmpegArgs.addAll(['-loop', '1', '-t', durSec, '-framerate', '30', '-i', overlayPaths[u]]);
          }

          final dimmingAlpha = config.backgroundDimming.clamp(0.0, 0.95).toStringAsFixed(2);
          filterChains.add('[0:v]setpts=PTS-STARTPTS,scale=$targetW:$targetH:force_original_aspect_ratio=increase,crop=$targetW:$targetH,setsar=1,format=yuv420p,drawbox=color=black@$dimmingAlpha:t=fill[bg]');
          filterChains.add('[bg][1:v]overlay=0:0[canvas0]');
          var currentCanvas = 'canvas0';

          double cumStart = 0.0;
          for (int u = 0; u < totalUnits; u++) {
            final durSec = unitConfigs[u]['durSec'] as double;
            final segStart = cumStart;
            final segEnd = segStart + durSec;
            cumStart += durSec;

            const fadeDur = 0.30;
            final safeFade = fadeDur.clamp(0.05, durSec * 0.20);
            final fadeOutStart = (durSec - safeFade).clamp(0.08, durSec);
            final nextCanvas = (u == totalUnits - 1) ? 'v' : 'canvas${u + 1}';
            final cropY = unitConfigs[u]['cropY'] as int? ?? 0;

            filterChains.add('[${u + 2}:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${segStart.toStringAsFixed(3)}/TB[ov$u]');
            filterChains.add('[$currentCanvas][ov$u]overlay=0:$cropY:enable=\'between(t,${segStart.toStringAsFixed(3)},${segEnd.toStringAsFixed(3)})\'[$nextCanvas]');
            currentCanvas = nextCanvas;
          }
        } else {
          ffmpegArgs.addAll(['-loop', '1', '-t', totalDurationStr, '-framerate', '30', '-i', baseFramePath]);

          for (int u = 0; u < totalUnits; u++) {
            final durSec = (unitConfigs[u]['durSec'] as double).toStringAsFixed(3);
            ffmpegArgs.addAll(['-loop', '1', '-t', durSec, '-framerate', '30', '-i', overlayPaths[u]]);
          }

          var currentCanvas = '0:v';
          double cumStart = 0.0;
          for (int u = 0; u < totalUnits; u++) {
            final durSec = unitConfigs[u]['durSec'] as double;
            final segStart = cumStart;
            final segEnd = segStart + durSec;
            cumStart += durSec;

            const fadeDur = 0.30;
            final safeFade = fadeDur.clamp(0.05, durSec * 0.20);
            final fadeOutStart = (durSec - safeFade).clamp(0.08, durSec);
            final nextCanvas = (u == totalUnits - 1) ? 'v' : 'canvas${u + 1}';
            final cropY = unitConfigs[u]['cropY'] as int? ?? 0;

            filterChains.add('[${u + 1}:v]fade=t=in:st=0:d=${safeFade.toStringAsFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${safeFade.toStringAsFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${segStart.toStringAsFixed(3)}/TB[ov$u]');
            filterChains.add('[$currentCanvas][ov$u]overlay=0:$cropY:enable=\'between(t,${segStart.toStringAsFixed(3)},${segEnd.toStringAsFixed(3)})\'[$nextCanvas]');
            currentCanvas = nextCanvas;
          }
        }

        // Audio Input
        final hasAudio = validAudioFiles.isNotEmpty;
        final audioInputIndex = isCustomVideo ? totalUnits + 2 : totalUnits + 1;
        if (hasAudio) {
          if (validAudioFiles.length == 1) {
            ffmpegArgs.addAll(['-i', validAudioFiles.first]);
          } else {
            final audioConcatFile = File('${sessionDir.path}/audio_segments.txt');
            final audioBuffer = StringBuffer();
            for (final p in validAudioFiles) {
              audioBuffer.writeln("file '$p'");
            }
            await audioConcatFile.writeAsString(audioBuffer.toString());
            final audioConcatInput = audioConcatFile.path.replaceAll(r'\', '/');
            ffmpegArgs.addAll(['-f', 'concat', '-safe', '0', '-i', audioConcatInput]);
          }
        }

        final filter = filterChains.join(';\n');
        final filterScriptFile = File('${sessionDir.path}/filter_graph.txt');
        await filterScriptFile.writeAsString(filter);
        final filterScriptInput = filterScriptFile.path.replaceAll(r'\', '/');

        ffmpegArgs.addAll(['-filter_complex_script', filterScriptInput]);
        ffmpegArgs.addAll(['-map', '[v]']);

        final isCopySafeAudio = validAudioFiles.every((p) {
          final lower = p.toLowerCase();
          return lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.aac');
        });

        if (hasAudio) {
          ffmpegArgs.addAll(['-map', '$audioInputIndex:a']);
          if (isCopySafeAudio) {
            ffmpegArgs.addAll(['-c:a', 'copy']);
          } else {
            ffmpegArgs.addAll(['-c:a', 'aac', '-b:a', '128k']);
          }
          ffmpegArgs.add('-shortest');
        }

        ffmpegArgs.addAll([
          '-t', totalDurationStr,
          '-c:v', 'libx264',
          '-preset', 'ultrafast',
        ]);
        if (!isCustomVideo) {
          ffmpegArgs.addAll(['-tune', 'stillimage']);
        }
        ffmpegArgs.addAll([
          '-crf', config.videoQuality.crf.toString(),
          '-pix_fmt', 'yuv420p',
          '-r', '30',
          '-threads', '0',
          '-movflags', '+faststart',
          renderOutputPath,
        ]);

        final sessionCompleter = Completer<dynamic>();
        final encodingStopwatch = Stopwatch()..start();
        double maxMonotonicRenderedSec = 0.0;
        double maxMonotonicProgress = 0.20;

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

        await FFmpegKit.executeWithArgumentsAsync(
          ffmpegArgs,
          (session) {
            if (!sessionCompleter.isCompleted) {
              sessionCompleter.complete(session);
            }
          },
          null,
          (statistics) {
            if (_isCancelled) return;
            final currentRenderedMs = max(0, statistics.getTime());
            final currentRenderedSec = min(currentRenderedMs / 1000.0, totalDurationSec);
            maxMonotonicRenderedSec = max(maxMonotonicRenderedSec, currentRenderedSec);

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
              ayahNumber: verses.first.verseNumber,
              currentAyahIndex: 1,
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
          throw Exception('تعذر رندر مقطع الفيديو: $logs');
        }

        if (!renderOutputFile.existsSync() || renderOutputFile.lengthSync() < 1024) {
          throw Exception(isEn ? 'Final video file not found' : 'تعذر العثور على ملف الفيديو النهائي');
        }

        final surahName = QuranMetadata.getSurahName(config.surahNumber);
        final finalOutputMp4File = File(
            '${tempDir.path}/Tabattal_${surahName}_${config.startAyah}-${config.endAyah}_$timestamp.mp4');
        await renderOutputFile.copy(finalOutputMp4File.path);

        controller.add(VideoRenderProgress(
          phase: VideoRenderPhase.completed,
          progress: 1.0,
          statusMessage: isEn ? 'Video created successfully!' : 'تم إنشاء مقطع الفيديو بنجاح!',
          outputPath: finalOutputMp4File.path,
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

  /// Saves the generated video file.
  /// On Desktop (Windows/macOS/Linux), opens the native Save File Dialog so the user can freely choose any destination directory and filename.
  /// On Mobile, saves to the system gallery via MediaStore / Photos.
  /// Returns `true` if saved successfully, `false` if an error occurred, or `null` if the user cancelled the dialog.
  static Future<bool?> saveVideo({
    required String filePath,
    required String suggestedName,
    String? album,
  }) async {
    final file = File(filePath);
    if (!await file.exists() || await file.length() == 0) {
      debugPrint('saveVideo error: file not found or empty: $filePath');
      return false;
    }

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final cleanSuggestedName = suggestedName.endsWith('.mp4')
            ? suggestedName
            : '$suggestedName.mp4';
        final saveLocation = await getSaveLocation(
          suggestedName: cleanSuggestedName,
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'MP4 Video',
              extensions: ['mp4'],
              mimeTypes: ['video/mp4'],
            ),
          ],
        );

        if (saveLocation == null) {
          // User dismissed or cancelled the save dialog
          return null;
        }

        final destinationFile = File(saveLocation.path);
        final parentDir = destinationFile.parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        await file.copy(destinationFile.path);
        return true;
      } catch (e) {
        debugPrint('Desktop saveVideo error: $e');
        return false;
      }
    } else {
      // Mobile platform (Android / iOS): Save directly to device gallery via Gal (MediaStore)
      try {
        try {
          await Gal.putVideo(filePath, album: album);
          return true;
        } catch (albumError) {
          debugPrint('Gal with album error: $albumError, retrying without album');
          await Gal.putVideo(filePath);
          return true;
        }
      } catch (e) {
        debugPrint('Gal saveVideo error: $e');
        return false;
      }
    }
  }

  /// Shares the generated video file without accompanying caption text.
  static Future<void> shareOutput({
    required String filePath,
    String? title,
  }) async {
    final file = File(filePath);
    if (await file.exists()) {
      final isVideo = filePath.toLowerCase().endsWith('.mp4');
      final normalizedPath = Platform.isWindows
          ? file.path.replaceAll('/', '\\')
          : file.path;
      final fileName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : (isVideo ? 'Tabattal_Video.mp4' : 'Tabattal_Image.png');
      if (Platform.isWindows) {
        const channel = MethodChannel('dev.fluttercommunity.plus/share');
        await channel.invokeMethod<String>('share', <String, dynamic>{
          'paths': [normalizedPath],
          'mimeTypes': [isVideo ? 'video/mp4' : 'image/png'],
          'title': fileName,
          'text': '',
        });
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(
                normalizedPath,
                mimeType: isVideo ? 'video/mp4' : 'image/png',
                name: fileName,
              ),
            ],
          ),
        );
      }
    }
  }
}

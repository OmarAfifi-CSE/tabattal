import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/video_enums.dart';
import '../../bloc/video_studio_bloc.dart';
import '../../bloc/video_studio_event.dart';
import '../../bloc/video_studio_state.dart';
import 'video_background_player_view.dart';
import 'video_frame_painter.dart';

/// Renders the 100% WYSIWYG video frame on a hardware-accelerated Canvas.
/// The output matches the exported MP4 video down to the exact subpixel.
class VideoPreviewViewport extends StatelessWidget {
  final VideoStudioState state;
  final VoidCallback onTogglePlay;
  final VoidCallback? onReset;
  final ValueChanged<int>? onVerseIndexChanged;
  final VoidCallback? onOpenFullscreen;

  const VideoPreviewViewport({
    super.key,
    required this.state,
    required this.onTogglePlay,
    this.onReset,
    this.onVerseIndexChanged,
    this.onOpenFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = state.config;
    final verse = state.currentVerse;
    final totalVerses = state.verses.length;
    final currentIndex = state.currentVerseIndex;

    final pageNumber = QuranMetadata.getPageNumberForAyah(
      config.surahNumber,
      verse?.verseNumber ?? config.startAyah,
    );

    final double previewHeight;
    switch (config.aspectRatio) {
      case VideoAspectRatio.portrait9x16:
        previewHeight = 345.h;
        break;
      case VideoAspectRatio.square1x1:
        previewHeight = 260.h;
        break;
      case VideoAspectRatio.landscape16x9:
        previewHeight = 180.h;
        break;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Real Video Preview Card (100% WYSIWYG Canvas Rendering - Zero Overlays)
          Padding(
            padding: EdgeInsets.only(top: 10.h, bottom: 8.h, left: 16.w, right: 16.w),
            child: RepaintBoundary(
              child: SizedBox(
                height: previewHeight,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: config.aspectRatio.ratio,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 20,
                            spreadRadius: -1,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: StreamBuilder<Duration>(
                        stream: context.read<VideoStudioBloc>().playbackPositionStream,
                        initialData: context.read<VideoStudioBloc>().currentVersePosition,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? context.read<VideoStudioBloc>().currentVersePosition;
                          final cumulativePos = state.calculateCumulativePosition(state.currentVerseIndex, position);

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // 0. Video Background Player Layer (if custom video is active)
                              if (config.backgroundType == VideoBackgroundType.customVideo &&
                                  config.customVideoPath != null &&
                                  config.customVideoPath!.isNotEmpty)
                                RepaintBoundary(
                                  child: VideoBackgroundPlayerView(
                                    videoPath: config.customVideoPath!,
                                    isPlaying: state.isPlaying,
                                    dimming: config.backgroundDimming,
                                    resetSignal: state.playbackResetTrigger,
                                    currentPosition: cumulativePos,
                                  ),
                                ),

                              // 1. Static Base Frame Layer (Background / Luxury Card, Badges, Watermark - 100% Solid & Fixed)
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: VideoStaticFramePainter(
                                    config: config,
                                    verse: verse,
                                    includeBackground: config.backgroundType != VideoBackgroundType.customVideo,
                                  ),
                                ),
                              ),

                              // 2. Dynamic Center Content Layer (100% Solid & Real-time Word Tracking without initial fade)
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: VideoDynamicContentPainter(
                                    verse: verse,
                                    config: config,
                                    pageNumber: pageNumber,
                                    tafsirText: verse?.tafsir,
                                    translationText: verse?.translation,
                                    playbackPositionMs: position.inMilliseconds,
                                    wordTimings: state.currentVerseWordTimings,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Bottom Playback & Scrubber Controls Bar (Matching Fullscreen Modal structure with light luxury theme)
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 6.h),
            child: RepaintBoundary(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Real-time Video Playback Timeline Scrubber
                  if (state.totalVideoDuration > Duration.zero)
                    StreamBuilder<Duration>(
                      stream: context.read<VideoStudioBloc>().playbackPositionStream,
                      initialData: context.read<VideoStudioBloc>().currentVersePosition,
                      builder: (context, snapshot) {
                        final pos = snapshot.data ?? context.read<VideoStudioBloc>().currentVersePosition;
                        final cumulativePos = state.calculateCumulativePosition(state.currentVerseIndex, pos);
                        final posStr = VideoStudioState.formatDurationToMinutesSeconds(cumulativePos);
                        final totalStr = state.formattedTotalDuration ?? '0:00';
                        final totalMs = state.totalVideoDuration.inMilliseconds.toDouble();
                        final currentMs = cumulativePos.inMilliseconds.toDouble().clamp(0.0, totalMs > 0 ? totalMs : 0.0);

                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32.w,
                                child: Text(
                                  posStr,
                                  style: TextStyle(
                                    fontSize: 10.5.sp,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3.h,
                                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5.r),
                                    overlayShape: RoundSliderOverlayShape(overlayRadius: 10.r),
                                    activeTrackColor: AppColors.accentGold,
                                    inactiveTrackColor: AppColors.accentGold.withValues(alpha: 0.18),
                                    thumbColor: AppColors.accentGold,
                                  ),
                                  child: Slider(
                                    value: currentMs,
                                    min: 0.0,
                                    max: totalMs > 0 ? totalMs : 1.0,
                                    onChanged: (val) {
                                      context.read<VideoStudioBloc>().add(
                                            VideoStudioSeekRequested(
                                              Duration(milliseconds: val.round()),
                                            ),
                                          );
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 32.w,
                                child: Text(
                                  totalStr,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 10.5.sp,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // Verse indicator / step text
                  if (totalVerses > 0)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4.h),
                      child: Text(
                        config.startAyah == config.endAyah
                            ? l10n.videoStudioAyahOfSurah(
                                config.startAyah,
                                config.startAyah,
                                QuranMetadata.getSurahNameByLang(
                                  Localizations.localeOf(context).languageCode == 'en',
                                  config.surahNumber,
                                ),
                              )
                            : l10n.videoStudioAyahOfSurah(
                                verse?.verseNumber ?? (config.startAyah + currentIndex),
                                config.endAyah,
                                QuranMetadata.getSurahNameByLang(
                                  Localizations.localeOf(context).languageCode == 'en',
                                  config.surahNumber,
                                ),
                              ),
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Playback Controls Row (Reset on Start, Prev/Play/Next in Center, Fullscreen on End)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Reset / Replay Button (Start edge)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          onPressed: () {
                            if (onReset != null) {
                              onReset!();
                            } else {
                              context
                                  .read<VideoStudioBloc>()
                                  .add(const VideoStudioPlaybackReset());
                            }
                          },
                          icon: const Icon(Icons.replay_rounded),
                          iconSize: 20.r,
                          color: AppColors.accentGold,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: l10n.videoStudioReplayFromStart,
                        ),
                      ),

                      // 2. Center Controls in LTR
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Previous Verse Button
                            IconButton(
                              onPressed: currentIndex > 0 && onVerseIndexChanged != null
                                  ? () => onVerseIndexChanged!(currentIndex - 1)
                                  : null,
                              icon: const Icon(Icons.skip_previous_rounded),
                              iconSize: 22.r,
                              color: AppColors.accentGold,
                              disabledColor: AppColors.textSecondary.withValues(alpha: 0.3),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            SizedBox(width: 14.w),

                            // Main Play / Pause Button
                            InkWell(
                              onTap: onTogglePlay,
                              borderRadius: BorderRadius.circular(22.r),
                              child: Container(
                                width: 44.r,
                                height: 44.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accentGold,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentGold.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: state.isPreparingAudio
                                    ? Center(
                                        child: SizedBox(
                                          width: 20.r,
                                          height: 20.r,
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        state.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 26.r,
                                      ),
                              ),
                            ),
                            SizedBox(width: 14.w),

                            // Next Verse Button
                            IconButton(
                              onPressed: currentIndex < totalVerses - 1 && onVerseIndexChanged != null
                                  ? () => onVerseIndexChanged!(currentIndex + 1)
                                  : null,
                              icon: const Icon(Icons.skip_next_rounded),
                              iconSize: 22.r,
                              color: AppColors.accentGold,
                              disabledColor: AppColors.textSecondary.withValues(alpha: 0.3),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                      // 3. Fullscreen Button (End edge)
                      if (onOpenFullscreen != null)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: IconButton(
                            onPressed: onOpenFullscreen,
                            icon: const Icon(Icons.fullscreen_rounded),
                            iconSize: 22.r,
                            color: AppColors.accentGold,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: l10n.videoStudioFullscreenPreview,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}


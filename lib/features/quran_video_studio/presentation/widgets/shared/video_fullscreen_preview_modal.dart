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

class VideoFullscreenPreviewModal extends StatelessWidget {
  const VideoFullscreenPreviewModal({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<VideoStudioBloc>();
    return showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogCtx) {
        return BlocProvider.value(
          value: bloc,
          child: const VideoFullscreenPreviewModal(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<VideoStudioBloc, VideoStudioState>(
      builder: (context, state) {
        final config = state.config;
        final verse = state.currentVerse;
        final totalVerses = state.verses.length;
        final currentIndex = state.currentVerseIndex;

        final pageNumber = QuranMetadata.getPageNumberForAyah(
          config.surahNumber,
          verse?.verseNumber ?? config.startAyah,
        );

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Top Header Bar with Close Button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          // Pause audio if playing before closing
                          if (state.isPlaying) {
                            context
                                .read<VideoStudioBloc>()
                                .add(const VideoStudioPlaybackToggled());
                          }
                          Navigator.of(context).pop();
                        },
                        icon: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20.r,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppColors.accentGold,
                              size: 14.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              l10n.videoStudioFullscreenPreview,
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 40.w), // Balance close button spacing
                    ],
                  ),
                ),

                // 2. Center Video Frame Canvas Viewport (100% WYSIWYG Output Frame)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      child: AspectRatio(
                        aspectRatio: config.aspectRatio.ratio,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
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

                                  // 1. Static Base Frame Layer (Background, Luxury Card, Badges, Watermark - 100% Solid & Fixed)
                                  RepaintBoundary(
                                    child: CustomPaint(
                                      painter: VideoStaticFramePainter(
                                        config: config,
                                        verse: verse,
                                        includeBackground: config.backgroundType != VideoBackgroundType.customVideo,
                                      ),
                                    ),
                                  ),

                                  // 2. Dynamic Center Content Layer (100% Solid & Real-time Text Tracking)
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

                // 3. Bottom Playback Controls Bar (Cleanly separated below video frame)
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 12.h),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 32.w,
                                      child: Text(
                                        posStr,
                                        style: TextStyle(
                                          fontSize: 10.5.sp,
                                          color: Colors.white70,
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
                                          inactiveTrackColor: Colors.white24,
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
                                          color: Colors.white70,
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
                            padding: EdgeInsets.only(bottom: 6.h),
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
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        // Playback Controls Row: Centered Playback controls with Reset button on the side
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. Reset / Replay to initial Ayah Button on the side (Start edge)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: IconButton(
                                onPressed: () {
                                  context
                                      .read<VideoStudioBloc>()
                                      .add(const VideoStudioPlaybackReset());
                                },
                                icon: const Icon(Icons.replay_rounded),
                                color: AppColors.accentGold,
                                iconSize: 24.r,
                                tooltip: l10n.videoStudioReplayFromStart,
                              ),
                            ),

                            // 2. Playback Buttons Row perfectly centered in standard LTR
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Previous Verse Button
                                  IconButton(
                                    onPressed: currentIndex > 0
                                        ? () {
                                            context.read<VideoStudioBloc>().add(
                                                  VideoStudioActiveVerseIndexChanged(
                                                    currentIndex - 1,
                                                  ),
                                                );
                                          }
                                        : null,
                                    icon: const Icon(Icons.skip_previous_rounded),
                                    color: AppColors.accentGold,
                                    iconSize: 26.r,
                                    disabledColor: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  SizedBox(width: 16.w),

                                  // Main Play/Pause Action Button
                                  InkWell(
                                    onTap: () {
                                      context
                                          .read<VideoStudioBloc>()
                                          .add(const VideoStudioPlaybackToggled());
                                    },
                                    borderRadius: BorderRadius.circular(28.r),
                                    child: Container(
                                      width: 52.r,
                                      height: 52.r,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.accentGold,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accentGold.withValues(alpha: 0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: state.isPreparingAudio
                                          ? Center(
                                              child: SizedBox(
                                                width: 24.r,
                                                height: 24.r,
                                                child: const CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              state.isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 32.r,
                                            ),
                                    ),
                                  ),
                                  SizedBox(width: 16.w),

                                  // Next Verse Button
                                  IconButton(
                                    onPressed: currentIndex < totalVerses - 1
                                        ? () {
                                            context.read<VideoStudioBloc>().add(
                                                  VideoStudioActiveVerseIndexChanged(
                                                    currentIndex + 1,
                                                  ),
                                                );
                                          }
                                        : null,
                                    icon: const Icon(Icons.skip_next_rounded),
                                    color: AppColors.accentGold,
                                    iconSize: 26.r,
                                    disabledColor: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ],
                              ),
                            ),

                            // 3. Fullscreen Minimize / Exit Action Button on the opposite side (End edge)
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: IconButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.fullscreen_exit_rounded),
                                color: AppColors.accentGold,
                                iconSize: 26.r,
                                tooltip: l10n.videoStudioFullscreenPreview,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/video_studio_bloc.dart';
import '../bloc/video_studio_event.dart';
import '../bloc/video_studio_state.dart';
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
            child: Stack(
              children: [
                // 1. Center Video Preview Frame (100% WYSIWYG Canvas)
                Center(
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Static Base Frame Layer (Background, Luxury Card, Badges, Watermark - 100% Solid & Fixed)
                            CustomPaint(
                              painter: VideoStaticFramePainter(
                                config: config,
                                verse: verse,
                              ),
                              size: Size.infinite,
                            ),

                            // 2. Dynamic Center Content Layer (Recitation Fade: Fade-In at verse start, Fade-Out at verse end)
                            StreamBuilder<Duration>(
                              stream: context.read<VideoStudioBloc>().playbackPositionStream,
                              builder: (context, snapshot) {
                                final position = snapshot.data ?? Duration.zero;
                                double opacity = 1.0;

                                if (state.isPlaying &&
                                    !state.isPreparingAudio &&
                                    state.verseDurations.isNotEmpty &&
                                    currentIndex < state.verseDurations.length) {
                                  final totalMs = state.verseDurations[currentIndex].inMilliseconds;
                                  final posMs = position.inMilliseconds;
                                  const fadeMs = 450;

                                  // Exclude first verse from initial fade-in to prevent initial play flicker
                                  if (currentIndex > 0 && posMs > 0 && posMs < fadeMs) {
                                    opacity = (posMs / fadeMs).clamp(0.0, 1.0);
                                  } else if (posMs > totalMs - fadeMs && totalMs > fadeMs * 2) {
                                    opacity = ((totalMs - posMs) / fadeMs).clamp(0.0, 1.0);
                                  } else {
                                    opacity = 1.0;
                                  }
                                }

                                return Opacity(
                                  opacity: opacity,
                                  child: CustomPaint(
                                    key: ValueKey('fullscreen_content_${verse?.verseNumber}_${config.themePreset.id}_${config.aspectRatio.name}'),
                                    painter: VideoDynamicContentPainter(
                                      verse: verse,
                                      config: config,
                                      pageNumber: pageNumber,
                                      tafsirText: verse?.tafsir,
                                      translationText: verse?.translation,
                                    ),
                                    size: Size.infinite,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Top Header Bar with Close Button
                Positioned(
                  top: 8.h,
                  left: 16.w,
                  right: 16.w,
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
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 44), // Balancer
                    ],
                  ),
                ),

                // 3. Bottom Playback Controls Bar
                Positioned(
                  bottom: 12.h,
                  left: 20.w,
                  right: 20.w,
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
                        // Verse indicator / step text
                        if (totalVerses > 0)
                          Padding(
                            padding: EdgeInsets.only(bottom: 6.h),
                            child: Text(
                              l10n.videoStudioAyahOfSurah(
                                currentIndex + 1,
                                totalVerses,
                                QuranMetadata.getSurahName(config.surahNumber),
                              ),
                              style: TextStyle(
                                fontSize: 10.5.sp,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        // Playback Buttons Row in standard LTR so arrows point outward naturally
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
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

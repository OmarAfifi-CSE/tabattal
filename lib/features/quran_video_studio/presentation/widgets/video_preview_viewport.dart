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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Real Video Preview Card (100% WYSIWYG Canvas Rendering)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            height: 380.h,
            alignment: Alignment.center,
            child: AspectRatio(
              aspectRatio: config.aspectRatio.ratio,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
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

                    // 2. Dynamic Center Content Layer (100% Solid & Real-time Word Tracking without initial fade)
                    StreamBuilder<Duration>(
                      stream: context.read<VideoStudioBloc>().playbackPositionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;

                        return CustomPaint(
                          key: ValueKey('preview_content_${verse?.verseNumber}_${config.themePreset.id}_${config.aspectRatio.name}_${config.textDisplayMode.name}'),
                          painter: VideoDynamicContentPainter(
                            verse: verse,
                            config: config,
                            pageNumber: pageNumber,
                            tafsirText: verse?.tafsir,
                            translationText: verse?.translation,
                            playbackPositionMs: position.inMilliseconds,
                            wordTimings: state.currentVerseWordTimings,
                          ),
                        );
                      },
                    ),


                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 12.h),

          // 2. Playback and Navigation Control Bar (Cleanly positioned underneath with Zero Overflow)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ayah Range Indicator
                  Text(
                    l10n.videoStudioAyahOf(
                      verse?.verseNumber ?? config.startAyah,
                      state.verses.isNotEmpty ? state.verses.last.verseNumber : config.endAyah,
                    ),
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 8.w),

                  // Player Controls in standard LTR so arrows point outward naturally: [ |<< ] ( > ) [ >>| ]
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reset / Replay to initial Ayah button
                        IconButton(
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
                          iconSize: 19.r,
                          color: AppColors.accentGold,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'إعادة من البداية',
                        ),
                        SizedBox(width: 8.w),

                        // Previous Verse Button
                        IconButton(
                          onPressed: currentIndex > 0 && onVerseIndexChanged != null
                              ? () => onVerseIndexChanged!(currentIndex - 1)
                              : null,
                          icon: const Icon(Icons.skip_previous_rounded),
                          iconSize: 20.r,
                          color: AppColors.accentGold,
                          disabledColor: AppColors.textSecondary.withValues(alpha: 0.3),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        SizedBox(width: 8.w),

                        // Play / Pause Button
                        InkWell(
                          onTap: onTogglePlay,
                          borderRadius: BorderRadius.circular(20.r),
                          child: Container(
                            width: 38.r,
                            height: 38.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentGold,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentGold.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: state.isPreparingAudio
                                ? Center(
                                    child: SizedBox(
                                      width: 18.r,
                                      height: 18.r,
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
                                    size: 24.r,
                                  ),
                          ),
                        ),
                        SizedBox(width: 8.w),

                        // Next Verse Button
                        IconButton(
                          onPressed: currentIndex < totalVerses - 1 && onVerseIndexChanged != null
                              ? () => onVerseIndexChanged!(currentIndex + 1)
                              : null,
                          icon: const Icon(Icons.skip_next_rounded),
                          iconSize: 20.r,
                          color: AppColors.accentGold,
                          disabledColor: AppColors.textSecondary.withValues(alpha: 0.3),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  if (onOpenFullscreen != null) ...[
                    SizedBox(width: 8.w),
                    Container(
                      width: 1,
                      height: 16.h,
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                    ),
                    SizedBox(width: 6.w),
                    // Fullscreen Button
                    IconButton(
                      onPressed: onOpenFullscreen,
                      icon: const Icon(Icons.fullscreen_rounded),
                      iconSize: 22.r,
                      color: AppColors.accentGold,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: l10n.videoStudioFullscreenPreview,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/video_studio_bloc.dart';
import '../../bloc/video_studio_event.dart';
import '../../bloc/video_studio_state.dart';

/// High-performance 120 FPS responsive timeline scrubber for Quran Video Studio.
/// Smoothly decouples finger/cursor dragging from the audio position stream,
/// providing instantaneous UI response and real-time seek synchronization
/// without overloading audio/video decoders.
class VideoTimelineScrubber extends StatefulWidget {
  final VideoStudioState state;
  final bool isLandscape;
  final bool isDark;

  const VideoTimelineScrubber({
    super.key,
    required this.state,
    this.isLandscape = false,
    this.isDark = false,
  });

  @override
  State<VideoTimelineScrubber> createState() => _VideoTimelineScrubberState();
}

class _VideoTimelineScrubberState extends State<VideoTimelineScrubber> {
  bool _isDragging = false;
  double _dragMs = 0.0;
  DateTime _lastThrottledSeek = DateTime.fromMillisecondsSinceEpoch(0);

  void _onDragStart(double val) {
    setState(() {
      _isDragging = true;
      _dragMs = val;
    });
  }

  void _onDragChanged(double val) {
    setState(() {
      _dragMs = val;
    });

    final now = DateTime.now();
    if (now.difference(_lastThrottledSeek).inMilliseconds >= 120) {
      _lastThrottledSeek = now;
      context.read<VideoStudioBloc>().add(
            VideoStudioSeekRequested(
              Duration(milliseconds: val.round()),
            ),
          );
    }
  }

  void _onDragEnd(double val) {
    setState(() {
      _isDragging = false;
    });
    context.read<VideoStudioBloc>().add(
          VideoStudioSeekRequested(
            Duration(milliseconds: val.round()),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final totalMs = state.totalVideoDuration.inMilliseconds.toDouble();
    if (totalMs <= 0) return const SizedBox.shrink();

    final totalStr = state.formattedTotalDuration ?? '0:00';
    final isLandscape = widget.isLandscape;
    final isDark = widget.isDark;

    final textColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final inactiveTrackColor = isDark
        ? Colors.white24
        : AppColors.accentGold.withValues(alpha: 0.18);

    return StreamBuilder<Duration>(
      stream: context.read<VideoStudioBloc>().playbackPositionStream,
      initialData: context.read<VideoStudioBloc>().currentVersePosition,
      builder: (context, snapshot) {
        final bloc = context.read<VideoStudioBloc>();
        final liveState = bloc.state;
        final pos = snapshot.data ?? bloc.currentVersePosition;
        final cumulativePos = liveState.calculateCumulativePosition(liveState.currentVerseIndex, pos);

        final currentMs = _isDragging
            ? _dragMs.clamp(0.0, totalMs)
            : cumulativePos.inMilliseconds.toDouble().clamp(0.0, totalMs);

        final displayPos = _isDragging
            ? Duration(milliseconds: currentMs.round())
            : cumulativePos;
        final posStr = VideoStudioState.formatDurationToMinutesSeconds(displayPos);

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 2.0 : 2.w,
            vertical: isLandscape ? 1.0 : 1.h,
          ),
          child: Row(
            children: [
              SizedBox(
                width: isLandscape ? 34.0 : 40.w,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    posStr,
                    style: TextStyle(
                      fontSize: isLandscape ? 9.5 : 10.5.sp,
                      color: textColor,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: isLandscape ? 2.5 : 3.h,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: isLandscape ? 4.0 : 5.r,
                    ),
                    overlayShape: RoundSliderOverlayShape(
                      overlayRadius: isLandscape ? 8.0 : 10.r,
                    ),
                    activeTrackColor: AppColors.accentGold,
                    inactiveTrackColor: inactiveTrackColor,
                    thumbColor: AppColors.accentGold,
                  ),
                  child: Slider(
                    value: currentMs,
                    min: 0.0,
                    max: totalMs > 0 ? totalMs : 1.0,
                    onChangeStart: _onDragStart,
                    onChanged: _onDragChanged,
                    onChangeEnd: _onDragEnd,
                  ),
                ),
              ),
              SizedBox(
                width: isLandscape ? 34.0 : 40.w,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    totalStr,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: isLandscape ? 9.5 : 10.5.sp,
                      color: textColor,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

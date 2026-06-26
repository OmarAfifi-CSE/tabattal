import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_event.dart';
import '../bloc/audio/audio_state.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'audio_settings_sheet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MediaControlBar extends StatefulWidget {
  const MediaControlBar({super.key});

  @override
  State<MediaControlBar> createState() => _MediaControlBarState();
}

class _MediaControlBarState extends State<MediaControlBar> {
  int? _sleepTimerMinutes;

  void _showTimerConfirmationSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 13.sp,
          ),
        ),
        backgroundColor: AppColors.bronzeIcon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.r)),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(horizontal: 50.w, vertical: 20.h),
        duration: const Duration(seconds: 2),
        elevation: 4,
      ),
    );
  }

  void _handleSleepTimerSelection(int minutes) {
    setState(() => _sleepTimerMinutes = minutes == 0 ? null : minutes);
    if (minutes == 0) {
      context.read<AudioBloc>().add(const CancelSleepTimer());
      _showTimerConfirmationSnackBar('تم إلغاء المؤقت');
    } else {
      context.read<AudioBloc>().add(SetSleepTimer(Duration(minutes: minutes)));
      _showTimerConfirmationSnackBar('سيتم إيقاف التلاوة بعد $minutes دقائق');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.bronzeIcon, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopRow(context),
          SizedBox(height: 12.h),
          _buildPlaybackRow(),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildReciterButton(context)),
        _buildTimerAndCloseButtons(context),
      ],
    );
  }

  Widget _buildReciterButton(BuildContext context) {
    return GestureDetector(
      onTap: () => showAudioSettingsSheet(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.bronzeIcon.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.bronzeIcon, size: 24.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: BlocBuilder<AudioBloc, AudioState>(
                builder: (context, state) => Text(
                  context.read<AudioBloc>().currentReciter,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.menuItemText.copyWith(
                    color: AppColors.inkBrown,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerAndCloseButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<int>(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          offset: Offset(0, -180.h),
          onSelected: _handleSleepTimerSelection,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 0, child: Align(alignment: Alignment.centerRight, child: Text('إيقاف المؤقت', textDirection: TextDirection.rtl))),
            PopupMenuItem(value: 5, child: Align(alignment: Alignment.centerRight, child: Text('5 دقائق', textDirection: TextDirection.rtl))),
            PopupMenuItem(value: 10, child: Align(alignment: Alignment.centerRight, child: Text('10 دقائق', textDirection: TextDirection.rtl))),
            PopupMenuItem(value: 15, child: Align(alignment: Alignment.centerRight, child: Text('15 دقيقة', textDirection: TextDirection.rtl))),
            PopupMenuItem(value: 30, child: Align(alignment: Alignment.centerRight, child: Text('30 دقيقة', textDirection: TextDirection.rtl))),
            PopupMenuItem(value: 60, child: Align(alignment: Alignment.centerRight, child: Text('60 دقيقة', textDirection: TextDirection.rtl))),
          ],
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: _sleepTimerMinutes != null ? AppColors.bronzeDark : AppColors.inkBrown,
                  size: 24.sp,
                ),
                if (_sleepTimerMinutes != null)
                  Text(
                    '${_sleepTimerMinutes}m',
                    style: TextStyle(fontSize: 10.sp, color: AppColors.bronzeDark, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () => context.read<AudioBloc>().add(const StopAudio()),
          child: Container(
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: AppColors.inkBrown, size: 24.sp),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackRow() {
    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, state) {
        final isPlaying = state is AudioPlaying;
        final isLoading = state is AudioLoading;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 32.w),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous_rounded, color: AppColors.inkBrown, size: 32.sp),
                  onPressed: () {}, // Previous verse — placeholder
                ),
                SizedBox(width: 16.w),
                _buildPlayPauseButton(context, isPlaying: isPlaying, isLoading: isLoading),
                SizedBox(width: 16.w),
                IconButton(
                  icon: Icon(Icons.skip_next_rounded, color: AppColors.inkBrown, size: 32.sp),
                  onPressed: () {}, // Next verse — placeholder
                ),
              ],
            ),
            SizedBox(width: 32.w),
          ],
        );
      },
    );
  }

  Widget _buildPlayPauseButton(BuildContext context, {required bool isPlaying, required bool isLoading}) {
    return GestureDetector(
      onTap: () {
        if (isPlaying) {
          context.read<AudioBloc>().add(const PauseAudio());
        } else {
          context.read<AudioBloc>().add(const ResumeAudio());
        }
      },
      child: Container(
        width: 56.r,
        height: 56.r,
        decoration: const BoxDecoration(
          color: AppColors.bronzeDark,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 24.r,
                  height: 24.r,
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32.sp,
                ),
        ),
      ),
    );
  }
}

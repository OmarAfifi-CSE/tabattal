import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/app_snack_bar.dart';
import '../../../../../core/utils/reciter_localization.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_event.dart';
import '../../../bloc/audio/audio_state.dart';
import 'audio_settings_sheet_tablet.dart';

class MediaControlBarTablet extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const MediaControlBarTablet({
    super.key,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<MediaControlBarTablet> createState() => _MediaControlBarTabletState();
}

class _MediaControlBarTabletState extends State<MediaControlBarTablet> {
  int? _sleepTimerMinutes;
  DateTime? _timerEndTime;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showTimerConfirmationSnackBar(String message) {
    AppSnackBar.show(
      context,
      message: message,
      icon: Icons.timer_outlined,
      duration: const Duration(seconds: 2),
    );
  }

  void _handleSleepTimerSelection(int minutes) {
    _countdownTimer?.cancel();
    if (minutes == 0) {
      setState(() {
        _sleepTimerMinutes = null;
        _timerEndTime = null;
      });
      context.read<AudioBloc>().add(const CancelSleepTimer());
      final l10n = AppLocalizations.of(context)!;
      _showTimerConfirmationSnackBar(l10n.timerCancelled);
    } else {
      setState(() {
        _sleepTimerMinutes = minutes;
        _timerEndTime = DateTime.now().add(Duration(minutes: minutes));
      });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_timerEndTime != null) {
          final remaining = _timerEndTime!.difference(DateTime.now());
          if (remaining.isNegative) {
            timer.cancel();
            setState(() {
              _sleepTimerMinutes = null;
              _timerEndTime = null;
            });
          } else {
            setState(() {});
          }
        } else {
          timer.cancel();
        }
      });
      context.read<AudioBloc>().add(SetSleepTimer(Duration(minutes: minutes)));
      final l10n = AppLocalizations.of(context)!;
      _showTimerConfirmationSnackBar(l10n.sleepTimerStopped(minutes));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState: widget.isExpanded
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: _TabletExpandedPlayer(
        onToggleExpanded: widget.onToggleExpanded,
        sleepTimerMinutes: _sleepTimerMinutes,
        timerEndTime: _timerEndTime,
        onSleepTimerSelected: _handleSleepTimerSelection,
      ),
      secondChild: _TabletMiniPlayer(onToggleExpanded: widget.onToggleExpanded),
    );
  }
}

class _TabletExpandedPlayer extends StatelessWidget {
  final VoidCallback onToggleExpanded;
  final int? sleepTimerMinutes;
  final DateTime? timerEndTime;
  final ValueChanged<int> onSleepTimerSelected;

  const _TabletExpandedPlayer({
    required this.onToggleExpanded,
    required this.sleepTimerMinutes,
    required this.timerEndTime,
    required this.onSleepTimerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.bronzeIcon, width: 1.2.w),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.inkBrown,
                  size: 28.sp,
                ),
                onPressed: onToggleExpanded,
              ),
              const Expanded(child: _TabletReciterButton()),
              _TabletSleepTimerAndClose(
                sleepTimerMinutes: sleepTimerMinutes,
                timerEndTime: timerEndTime,
                onSleepTimerSelected: onSleepTimerSelected,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          const _TabletPlaybackRow(),
        ],
      ),
    );
  }
}

class _TabletMiniPlayer extends StatelessWidget {
  final VoidCallback onToggleExpanded;

  const _TabletMiniPlayer({required this.onToggleExpanded});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleExpanded,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(color: AppColors.bronzeIcon, width: 1.2.w),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: BlocBuilder<AudioBloc, AudioState>(
          builder: (context, state) {
            final isPlaying = state is AudioPlaying;
            final isLoading = state is AudioLoading;
            final isEn = Localizations.localeOf(context).languageCode == 'en';
            final audioBloc = context.read<AudioBloc>();
            final reciterName = ReciterLocalization.localize(
              context,
              audioBloc.currentReciter,
            );
            final categoryName = ReciterLocalization.localize(
              context,
              audioBloc.currentCategory,
            );

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.multitrack_audio_rounded,
                        color: AppColors.bronzeIcon,
                        size: 24.sp,
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          '$reciterName ($categoryName)',
                          overflow: TextOverflow.ellipsis,
                          textDirection:
                              isEn ? TextDirection.ltr : TextDirection.rtl,
                          style: AppTextStyles.menuItemText.copyWith(
                            color: AppColors.inkBrown,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabletPlayPauseButton(
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      size: 40.r,
                      iconSize: 24.sp,
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: AppColors.inkBrown,
                      size: 28.sp,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabletReciterButton extends StatelessWidget {
  const _TabletReciterButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showAudioSettingsSheetTablet(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.bronzeIcon.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.bronzeIcon,
              size: 24.sp,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: BlocBuilder<AudioBloc, AudioState>(
                builder: (context, state) {
                  final isEn =
                      Localizations.localeOf(context).languageCode == 'en';
                  final audioBloc = context.read<AudioBloc>();
                  final reciterName = ReciterLocalization.localize(
                    context,
                    audioBloc.currentReciter,
                  );
                  return Text(
                    reciterName,
                    textAlign: isEn ? TextAlign.left : TextAlign.right,
                    style: AppTextStyles.menuItemText.copyWith(
                      color: AppColors.inkBrown,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabletSleepTimerAndClose extends StatelessWidget {
  final int? sleepTimerMinutes;
  final DateTime? timerEndTime;
  final ValueChanged<int> onSleepTimerSelected;

  const _TabletSleepTimerAndClose({
    required this.sleepTimerMinutes,
    required this.timerEndTime,
    required this.onSleepTimerSelected,
  });

  String _formatRemainingTime(Duration duration) {
    if (duration.isNegative) return '00:00';
    final m = duration.inMinutes.toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<int>(
          splashRadius: 0.1,
          color: AppColors.cardCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          offset: Offset(0, -180.h),
          onSelected: onSleepTimerSelected,
          itemBuilder: (ctx) {
            final l10n = AppLocalizations.of(ctx)!;
            return [
              PopupMenuItem(
                value: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(l10n.timerStop, textDirection: TextDirection.rtl),
                ),
              ),
              PopupMenuItem(
                value: 5,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.timerMinutes5,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 10,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.timerMinutes10,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 15,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.timerMinutes15,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 30,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.timerMinutes30,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 60,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.timerMinutes60,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ];
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: sleepTimerMinutes != null
                      ? AppColors.bronzeDark
                      : AppColors.inkBrown,
                  size: 24.sp,
                ),
                if (timerEndTime != null)
                  Text(
                    _formatRemainingTime(timerEndTime!.difference(DateTime.now())),
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.bronzeDark,
                      fontWeight: FontWeight.bold,
                    ),
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
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: AppColors.inkBrown, size: 24.sp),
          ),
        ),
      ],
    );
  }
}

class _TabletPlaybackRow extends StatelessWidget {
  const _TabletPlaybackRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, state) {
        final isPlaying = state is AudioPlaying;
        final isLoading = state is AudioLoading;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 8.w),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.fast_rewind_rounded,
                      color: AppColors.inkBrown,
                      size: 30.sp,
                    ),
                    onPressed: () =>
                        context.read<AudioBloc>().add(const PreviousSurah()),
                  ),
                  SizedBox(width: 4.w),
                  IconButton(
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: AppColors.inkBrown,
                      size: 32.sp,
                    ),
                    onPressed: () =>
                        context.read<AudioBloc>().add(const PreviousAyah()),
                  ),
                  SizedBox(width: 8.w),
                  _TabletPlayPauseButton(
                    isPlaying: isPlaying,
                    isLoading: isLoading,
                    size: 56.r,
                    iconSize: 32.sp,
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: AppColors.inkBrown,
                      size: 32.sp,
                    ),
                    onPressed: () =>
                        context.read<AudioBloc>().add(const NextAyah()),
                  ),
                  SizedBox(width: 4.w),
                  IconButton(
                    icon: Icon(
                      Icons.fast_forward_rounded,
                      color: AppColors.inkBrown,
                      size: 30.sp,
                    ),
                    onPressed: () =>
                        context.read<AudioBloc>().add(const NextSurah()),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
          ],
        );
      },
    );
  }
}

class _TabletPlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final double size;
  final double iconSize;

  const _TabletPlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isPlaying) {
          context.read<AudioBloc>().add(const PauseAudio());
        } else {
          context.read<AudioBloc>().add(const ResumeAudio());
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.bronzeDark,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isLoading
              ? CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: (iconSize * 0.75) / 2,
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.cardCream,
                  size: iconSize,
                ),
        ),
      ),
    );
  }
}

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
import '../../bloc/audio_bloc.dart';
import '../../bloc/audio_event.dart';
import '../../bloc/audio_state.dart';
import '../shared/sleep_timer_selector_menu.dart';
import 'audio_settings_sheet_mobile.dart';

class MediaControlBarMobile extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const MediaControlBarMobile({
    super.key,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<MediaControlBarMobile> createState() => _MediaControlBarMobileState();
}

class _MediaControlBarMobileState extends State<MediaControlBarMobile> {
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
      firstChild: _MobileExpandedPlayer(
        onToggleExpanded: widget.onToggleExpanded,
        sleepTimerMinutes: _sleepTimerMinutes,
        timerEndTime: _timerEndTime,
        onSleepTimerSelected: _handleSleepTimerSelection,
      ),
      secondChild: _MobileMiniPlayer(onToggleExpanded: widget.onToggleExpanded),
    );
  }
}

class _MobileExpandedPlayer extends StatelessWidget {
  final VoidCallback onToggleExpanded;
  final int? sleepTimerMinutes;
  final DateTime? timerEndTime;
  final ValueChanged<int> onSleepTimerSelected;

  const _MobileExpandedPlayer({
    required this.onToggleExpanded,
    required this.sleepTimerMinutes,
    required this.timerEndTime,
    required this.onSleepTimerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.bronzeIcon, width: 1.2),
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
                  size: 24.sp,
                ),
                onPressed: onToggleExpanded,
              ),
              const Expanded(child: _MobileReciterButton()),
              _MobileSleepTimerAndClose(
                sleepTimerMinutes: sleepTimerMinutes,
                timerEndTime: timerEndTime,
                onSleepTimerSelected: onSleepTimerSelected,
              ),
            ],
          ),
          const _MobilePlaybackRow(),
        ],
      ),
    );
  }
}

class _MobileMiniPlayer extends StatelessWidget {
  final VoidCallback onToggleExpanded;

  const _MobileMiniPlayer({required this.onToggleExpanded});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleExpanded,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.bronzeIcon, width: 1.2),
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
                        size: 20.sp,
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          '$reciterName ($categoryName)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection:
                              isEn ? TextDirection.ltr : TextDirection.rtl,
                          style: AppTextStyles.menuItemText.copyWith(
                            color: AppColors.inkBrown,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MobilePlayPauseButton(
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      size: 34.r,
                      iconSize: 20.sp,
                    ),
                    SizedBox(width: 6.w),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: AppColors.inkBrown,
                      size: 22.sp,
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

class _MobileReciterButton extends StatelessWidget {
  const _MobileReciterButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showAudioSettingsSheetMobile(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.bronzeIcon.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.bronzeIcon,
              size: 20.sp,
            ),
            SizedBox(width: 4.w),
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
                    maxLines: 1,
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

class _MobileSleepTimerAndClose extends StatelessWidget {
  final int? sleepTimerMinutes;
  final DateTime? timerEndTime;
  final ValueChanged<int> onSleepTimerSelected;

  const _MobileSleepTimerAndClose({
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
        SleepTimerSelectorMenu(
          selectedMinutes: sleepTimerMinutes,
          onSelected: onSleepTimerSelected,
          itemHeight: 36.h,
          maxHeight: 150.h,
          itemFontSize: 12.5.sp,
          menuWidth: 135.w,
          trigger: Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
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
                      fontWeight: FontWeight.w600,
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
            padding: EdgeInsets.all(3.r),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close,
              color: AppColors.inkBrown,
              size: 24.sp,
            ),
          ),
        ),
      ],
    );
  }
}

class _MobilePlaybackRow extends StatelessWidget {
  const _MobilePlaybackRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, state) {
        final isPlaying = state is AudioPlaying;
        final isLoading = state is AudioLoading;

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.fast_rewind_rounded,
                      color: AppColors.inkBrown,
                      size: 22.sp,
                    ),
                    onPressed: () =>
                        context.read<AudioBloc>().add(const PreviousSurah()),
                  ),
                  SizedBox(width: 6.w),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: AppColors.inkBrown,
                      size: 24.sp,
                    ),
                    onPressed: () =>
                        context.read<AudioBloc>().add(const PreviousAyah()),
                  ),
                  SizedBox(width: 10.w),
                  _MobilePlayPauseButton(
                    isPlaying: isPlaying,
                    isLoading: isLoading,
                    size: 40.r,
                    iconSize: 22.sp,
                  ),
                  SizedBox(width: 10.w),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: AppColors.inkBrown,
                      size: 24.sp,
                    ),
                    onPressed: () =>
                        context.read<AudioBloc>().add(const NextAyah()),
                  ),
                  SizedBox(width: 6.w),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.fast_forward_rounded,
                      color: AppColors.inkBrown,
                      size: 22.sp,
                    ),
                    onPressed: () =>
                        context.read<AudioBloc>().add(const NextSurah()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobilePlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final double size;
  final double iconSize;

  const _MobilePlayPauseButton({
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

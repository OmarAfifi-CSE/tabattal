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
import '../sleep_timer_selector_menu.dart';
import 'audio_settings_sheet_desktop.dart';

class MediaControlBarDesktop extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const MediaControlBarDesktop({
    super.key,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<MediaControlBarDesktop> createState() => _MediaControlBarDesktopState();
}

class _MediaControlBarDesktopState extends State<MediaControlBarDesktop> {
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
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    if (isLandscape) {
      return AnimatedCrossFade(
        duration: const Duration(milliseconds: 250),
        crossFadeState: widget.isExpanded
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        firstChild: _DesktopLandscapeHorizonBar(
          onToggleExpanded: widget.onToggleExpanded,
          sleepTimerMinutes: _sleepTimerMinutes,
          timerEndTime: _timerEndTime,
          onSleepTimerSelected: _handleSleepTimerSelection,
        ),
        secondChild: _DesktopLandscapeWhisperingPill(
          onToggleExpanded: widget.onToggleExpanded,
        ),
      );
    }

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState: widget.isExpanded
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: _DesktopExpandedPlayer(
        onToggleExpanded: widget.onToggleExpanded,
        sleepTimerMinutes: _sleepTimerMinutes,
        timerEndTime: _timerEndTime,
        onSleepTimerSelected: _handleSleepTimerSelection,
      ),
      secondChild: _DesktopMiniPlayer(onToggleExpanded: widget.onToggleExpanded),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDSCAPE: The 1-Row Luxury Horizon Bar (44dp Height)
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopLandscapeHorizonBar extends StatelessWidget {
  final VoidCallback onToggleExpanded;
  final int? sleepTimerMinutes;
  final DateTime? timerEndTime;
  final ValueChanged<int> onSleepTimerSelected;

  const _DesktopLandscapeHorizonBar({
    required this.onToggleExpanded,
    required this.sleepTimerMinutes,
    required this.timerEndTime,
    required this.onSleepTimerSelected,
  });

  static String _formatRemainingTime(Duration duration) {
    if (duration.isNegative) return '00:00';
    final m = duration.inMinutes.toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Container(
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.cardCream.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: AppColors.accentGold.withValues(alpha: 0.45),
          width: 1.0.r,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Right/Start: Reciter Capsule ──
          GestureDetector(
            onTap: () => showAudioSettingsSheetDesktop(context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.surfaceCream.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.bronzeIcon.withValues(alpha: 0.3),
                  width: 0.8.r,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.multitrack_audio_rounded,
                    color: AppColors.bronzeDark,
                    size: 15.sp,
                  ),
                  SizedBox(width: 4.w),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 120.w),
                    child: BlocBuilder<AudioBloc, AudioState>(
                      builder: (context, state) {
                        final audioBloc = context.read<AudioBloc>();
                        final reciterName = ReciterLocalization.localize(
                          context,
                          audioBloc.currentReciter,
                        );
                        return Text(
                          reciterName,
                          style: AppTextStyles.menuItemText.copyWith(
                            color: AppColors.inkBrown,
                            fontSize: 12.0.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textDirection:
                              isEn ? TextDirection.ltr : TextDirection.rtl,
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.bronzeIcon,
                    size: 16.sp,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: 6.w),
          Container(
            width: 1.w,
            height: 16.h,
            color: AppColors.bronzeIcon.withValues(alpha: 0.25),
          ),
          SizedBox(width: 6.w),

          // ── Center: Playback Engine (LTR) ──
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 26.w, minHeight: 26.h),
                  icon: Icon(
                    Icons.fast_rewind_rounded,
                    color: AppColors.inkBrown,
                    size: 17.sp,
                  ),
                  onPressed: () =>
                      context.read<AudioBloc>().add(const PreviousSurah()),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 26.w, minHeight: 26.h),
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: AppColors.inkBrown,
                    size: 19.sp,
                  ),
                  onPressed: () =>
                      context.read<AudioBloc>().add(const PreviousAyah()),
                ),
                SizedBox(width: 2.w),
                BlocBuilder<AudioBloc, AudioState>(
                  builder: (context, state) {
                    final isPlaying = state is AudioPlaying;
                    final isLoading = state is AudioLoading;
                    return _DesktopPlayPauseButton(
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      size: 32.r,
                      iconSize: 18.sp,
                    );
                  },
                ),
                SizedBox(width: 2.w),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 26.w, minHeight: 26.h),
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: AppColors.inkBrown,
                    size: 19.sp,
                  ),
                  onPressed: () =>
                      context.read<AudioBloc>().add(const NextAyah()),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 26.w, minHeight: 26.h),
                  icon: Icon(
                    Icons.fast_forward_rounded,
                    color: AppColors.inkBrown,
                    size: 17.sp,
                  ),
                  onPressed: () =>
                      context.read<AudioBloc>().add(const NextSurah()),
                ),
              ],
            ),
          ),

          SizedBox(width: 6.w),
          Container(
            width: 1.w,
            height: 16.h,
            color: AppColors.bronzeIcon.withValues(alpha: 0.25),
          ),
          SizedBox(width: 6.w),

          // ── Left/End: Timer, Minimize, Close ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SleepTimerSelectorMenu(
                selectedMinutes: sleepTimerMinutes,
                onSelected: onSleepTimerSelected,
                itemHeight: 32.h,
                maxHeight: 160.h,
                itemFontSize: 11.5.sp,
                menuWidth: 120.w,
                trigger: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: sleepTimerMinutes != null
                            ? AppColors.bronzeDark
                            : AppColors.inkBrown,
                        size: 15.sp,
                      ),
                      if (timerEndTime != null) ...[
                        SizedBox(width: 2.w),
                        Text(
                          _formatRemainingTime(
                            timerEndTime!.difference(DateTime.now()),
                          ),
                          style: TextStyle(
                            fontSize: 8.5.sp,
                            color: AppColors.bronzeDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 24.w, minHeight: 24.h),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.inkBrown,
                  size: 18.sp,
                ),
                onPressed: onToggleExpanded,
              ),
              SizedBox(width: 2.w),
              GestureDetector(
                onTap: () => context.read<AudioBloc>().add(const StopAudio()),
                child: Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: AppColors.inkBrown,
                    size: 13.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDSCAPE: The Whispering Pill (32dp Height)
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopLandscapeWhisperingPill extends StatelessWidget {
  final VoidCallback onToggleExpanded;

  const _DesktopLandscapeWhisperingPill({required this.onToggleExpanded});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return GestureDetector(
      onTap: onToggleExpanded,
      child: Container(
        height: 32.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: AppColors.cardCream.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: AppColors.accentGold.withValues(alpha: 0.45),
            width: 1.0.r,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocBuilder<AudioBloc, AudioState>(
              builder: (context, state) {
                final isPlaying = state is AudioPlaying;
                final isLoading = state is AudioLoading;
                return _DesktopPlayPauseButton(
                  isPlaying: isPlaying,
                  isLoading: isLoading,
                  size: 22.r,
                  iconSize: 13.sp,
                );
              },
            ),
            SizedBox(width: 6.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 110.w),
              child: BlocBuilder<AudioBloc, AudioState>(
                builder: (context, state) {
                  final audioBloc = context.read<AudioBloc>();
                  final reciterName = ReciterLocalization.localize(
                    context,
                    audioBloc.currentReciter,
                  );
                  return Text(
                    reciterName,
                    style: AppTextStyles.menuItemText.copyWith(
                      color: AppColors.inkBrown,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textDirection:
                        isEn ? TextDirection.ltr : TextDirection.rtl,
                  );
                },
              ),
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.inkBrown,
              size: 16.sp,
            ),
            SizedBox(width: 4.w),
            GestureDetector(
              onTap: () => context.read<AudioBloc>().add(const StopAudio()),
              child: Container(
                padding: EdgeInsets.all(2.r),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: AppColors.inkBrown,
                  size: 12.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PORTRAIT: Expanded Player
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopExpandedPlayer extends StatelessWidget {
  final VoidCallback onToggleExpanded;
  final int? sleepTimerMinutes;
  final DateTime? timerEndTime;
  final ValueChanged<int> onSleepTimerSelected;

  const _DesktopExpandedPlayer({
    required this.onToggleExpanded,
    required this.sleepTimerMinutes,
    required this.timerEndTime,
    required this.onSleepTimerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.bronzeIcon, width: 1.2.w),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.inkBrown,
                  size: 22.sp,
                ),
                onPressed: onToggleExpanded,
              ),
              const Expanded(child: _DesktopReciterButton()),
              _DesktopSleepTimerAndClose(
                sleepTimerMinutes: sleepTimerMinutes,
                timerEndTime: timerEndTime,
                onSleepTimerSelected: onSleepTimerSelected,
              ),
            ],
          ),
          SizedBox(height: 4.h),
          const _DesktopPlaybackRow(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PORTRAIT: Mini Player
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopMiniPlayer extends StatelessWidget {
  final VoidCallback onToggleExpanded;

  const _DesktopMiniPlayer({required this.onToggleExpanded});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleExpanded,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.bronzeIcon, width: 1.2.w),
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
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.multitrack_audio_rounded,
                        color: AppColors.bronzeIcon,
                        size: 18.sp,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          '$reciterName • $categoryName',
                          overflow: TextOverflow.ellipsis,
                          textDirection:
                              isEn ? TextDirection.ltr : TextDirection.rtl,
                          style: AppTextStyles.menuItemText.copyWith(
                            color: AppColors.inkBrown,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.bold,
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
                    _DesktopPlayPauseButton(
                      isPlaying: isPlaying,
                      isLoading: isLoading,
                      size: 32.r,
                      iconSize: 18.sp,
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: AppColors.inkBrown,
                      size: 20.sp,
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

class _DesktopReciterButton extends StatelessWidget {
  const _DesktopReciterButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showAudioSettingsSheetDesktop(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 6.w),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.bronzeIcon.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.bronzeIcon,
              size: 18.sp,
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
                    textAlign: isEn ? TextAlign.left : TextAlign.right,
                    style: AppTextStyles.menuItemText.copyWith(
                      color: AppColors.inkBrown,
                      fontSize: 13.sp,
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

class _DesktopSleepTimerAndClose extends StatelessWidget {
  final int? sleepTimerMinutes;
  final DateTime? timerEndTime;
  final ValueChanged<int> onSleepTimerSelected;

  const _DesktopSleepTimerAndClose({
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
          itemHeight: 34.h,
          maxHeight: 160.h,
          itemFontSize: 12.sp,
          menuWidth: 120.w,
          trigger: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: sleepTimerMinutes != null
                      ? AppColors.bronzeDark
                      : AppColors.inkBrown,
                  size: 18.sp,
                ),
                if (timerEndTime != null)
                  Text(
                    _formatRemainingTime(timerEndTime!.difference(DateTime.now())),
                    style: TextStyle(
                      fontSize: 8.5.sp,
                      color: AppColors.bronzeDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: 4.w),
        GestureDetector(
          onTap: () => context.read<AudioBloc>().add(const StopAudio()),
          child: Container(
            padding: EdgeInsets.all(3.r),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: AppColors.inkBrown, size: 18.sp),
          ),
        ),
      ],
    );
  }
}

class _DesktopPlaybackRow extends StatelessWidget {
  const _DesktopPlaybackRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, state) {
        final isPlaying = state is AudioPlaying;
        final isLoading = state is AudioLoading;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                icon: Icon(
                  Icons.fast_rewind_rounded,
                  color: AppColors.inkBrown,
                  size: 22.sp,
                ),
                onPressed: () =>
                    context.read<AudioBloc>().add(const PreviousSurah()),
              ),
              SizedBox(width: 2.w),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                icon: Icon(
                  Icons.skip_previous_rounded,
                  color: AppColors.inkBrown,
                  size: 24.sp,
                ),
                onPressed: () =>
                    context.read<AudioBloc>().add(const PreviousAyah()),
              ),
              SizedBox(width: 6.w),
              _DesktopPlayPauseButton(
                isPlaying: isPlaying,
                isLoading: isLoading,
                size: 42.r,
                iconSize: 24.sp,
              ),
              SizedBox(width: 6.w),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                icon: Icon(
                  Icons.skip_next_rounded,
                  color: AppColors.inkBrown,
                  size: 24.sp,
                ),
                onPressed: () =>
                    context.read<AudioBloc>().add(const NextAyah()),
              ),
              SizedBox(width: 2.w),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
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
        );
      },
    );
  }
}

class _DesktopPlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final double size;
  final double iconSize;

  const _DesktopPlayPauseButton({
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

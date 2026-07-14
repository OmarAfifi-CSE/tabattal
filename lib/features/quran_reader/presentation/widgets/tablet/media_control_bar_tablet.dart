import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_event.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../../../../core/theme/app_text_styles.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'audio_settings_sheet_tablet.dart';
import '../../../../../core/utils/reciter_localization.dart';

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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.cardCream,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 13,
          ),
        ),
        backgroundColor: AppColors.bronzeIcon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        duration: const Duration(seconds: 2),
        elevation: 4,
      ),
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
            setState(() {}); // trigger rebuild to update countdown text
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
      crossFadeState: widget.isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: _buildExpandedPlayer(context),
      secondChild: _buildMiniPlayer(context),
    );
  }

  Widget _buildExpandedPlayer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.bronzeIcon, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopRow(context),
          const SizedBox(height: 12),
          _buildPlaybackRow(),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggleExpanded,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.bronzeIcon, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: BlocBuilder<AudioBloc, AudioState>(
          builder: (context, state) {
            final isPlaying = state is AudioPlaying;
            final isLoading = state is AudioLoading;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.multitrack_audio_rounded, color: AppColors.bronzeIcon, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      ReciterLocalization.localize(context, context.read<AudioBloc>().currentReciter),
                      textDirection: Localizations.localeOf(context).languageCode == 'en' ? TextDirection.ltr : TextDirection.rtl,
                      style: AppTextStyles.menuItemText.copyWith(
                        color: AppColors.inkBrown,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPlayPauseButton(context, isPlaying: isPlaying, isLoading: isLoading, size: 40, iconSize: 24),
                    const SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.inkBrown, size: 28),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.inkBrown, size: 28),
          onPressed: widget.onToggleExpanded,
        ),
        Expanded(child: _buildReciterButton(context)),
        _buildTimerAndCloseButtons(context),
      ],
    );
  }

  Widget _buildReciterButton(BuildContext context) {
    return GestureDetector(
      onTap: () => showAudioSettingsSheetTablet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.bronzeIcon.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.bronzeIcon, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: BlocBuilder<AudioBloc, AudioState>(
                builder: (context, state) {
                  final isEn = Localizations.localeOf(context).languageCode == 'en';
                  return Text(
                    ReciterLocalization.localize(context, context.read<AudioBloc>().currentReciter),
                    textAlign: isEn ? TextAlign.left : TextAlign.right,
                    style: AppTextStyles.menuItemText.copyWith(
                      color: AppColors.inkBrown,
                      fontSize: 14,
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

  Widget _buildTimerAndCloseButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<int>(
          splashRadius: 0.1,
          color: AppColors.cardCream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          offset: const Offset(0, -180),
          onSelected: _handleSleepTimerSelection,
          itemBuilder: (ctx) {
            final l10n = AppLocalizations.of(ctx)!;
            return [
              PopupMenuItem(value: 0, child: Align(alignment: Alignment.centerRight, child: Text(l10n.timerStop, textDirection: TextDirection.rtl))),
              PopupMenuItem(value: 5, child: Align(alignment: Alignment.centerRight, child: Text(l10n.timerMinutes5, textDirection: TextDirection.rtl))),
              PopupMenuItem(value: 10, child: Align(alignment: Alignment.centerRight, child: Text(l10n.timerMinutes10, textDirection: TextDirection.rtl))),
              PopupMenuItem(value: 15, child: Align(alignment: Alignment.centerRight, child: Text(l10n.timerMinutes15, textDirection: TextDirection.rtl))),
              PopupMenuItem(value: 30, child: Align(alignment: Alignment.centerRight, child: Text(l10n.timerMinutes30, textDirection: TextDirection.rtl))),
              PopupMenuItem(value: 60, child: Align(alignment: Alignment.centerRight, child: Text(l10n.timerMinutes60, textDirection: TextDirection.rtl))),
            ];
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: _sleepTimerMinutes != null ? AppColors.bronzeDark : AppColors.inkBrown,
                  size: 24,
                ),
                if (_timerEndTime != null)
                  Text(
                    _formatRemainingTime(_timerEndTime!.difference(DateTime.now())),
                    style: TextStyle(fontSize: 10, color: AppColors.bronzeDark, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.read<AudioBloc>().add(const StopAudio()),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: AppColors.inkBrown, size: 24),
          ),
        ),
      ],
    );
  }

  String _formatRemainingTime(Duration duration) {
    if (duration.isNegative) return '00:00';
    final m = duration.inMinutes.toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildPlaybackRow() {
    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, state) {
        final isPlaying = state is AudioPlaying;
        final isLoading = state is AudioLoading;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.fast_rewind_rounded, color: AppColors.inkBrown, size: 30),
                    onPressed: () => context.read<AudioBloc>().add(const PreviousSurah()),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded, color: AppColors.inkBrown, size: 32),
                    onPressed: () => context.read<AudioBloc>().add(const PreviousAyah()),
                  ),
                  const SizedBox(width: 8),
                  _buildPlayPauseButton(context, isPlaying: isPlaying, isLoading: isLoading, size: 56, iconSize: 32),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded, color: AppColors.inkBrown, size: 32),
                    onPressed: () => context.read<AudioBloc>().add(const NextAyah()),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.fast_forward_rounded, color: AppColors.inkBrown, size: 30),
                    onPressed: () => context.read<AudioBloc>().add(const NextSurah()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }

  Widget _buildPlayPauseButton(BuildContext context, {required bool isPlaying, required bool isLoading, required double size, required double iconSize}) {
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
              ? SizedBox(
                  width: iconSize * 0.75,
                  height: iconSize * 0.75,
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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

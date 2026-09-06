import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/bloc/volume/app_volume_cubit.dart';
import '../../../../../core/bloc/volume/app_volume_state.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/app_localizations.dart';

/// Reusable luxury volume capsule widget for desktop and web media bars.
class AudioVolumeCapsule extends StatefulWidget {
  final double height;
  final double sliderWidth;
  final bool showPercent;

  const AudioVolumeCapsule({
    super.key,
    this.height = 26.0,
    this.sliderWidth = 55.0,
    this.showPercent = true,
  });

  @override
  State<AudioVolumeCapsule> createState() => _AudioVolumeCapsuleState();
}

class _AudioVolumeCapsuleState extends State<AudioVolumeCapsule> {
  bool _isHovered = false;

  void _handleScroll(PointerScrollEvent event, BuildContext context, double currentVolume) {
    final delta = event.scrollDelta.dy < 0 ? 0.05 : -0.05;
    final newVolume = (currentVolume + delta).clamp(0.0, 1.0);
    context.read<AppVolumeCubit>().setVolume(newVolume);
  }

  @override
  Widget build(BuildContext context) {
    AppVolumeCubit? cubit;
    try {
      cubit = context.read<AppVolumeCubit>();
    } catch (_) {}

    if (cubit == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);

    return BlocBuilder<AppVolumeCubit, AppVolumeState>(
      bloc: cubit,
      builder: (context, state) {
        final volume = state.volume;
        final isMuted = state.isMuted || volume == 0.0;
        final percent = (volume * 100).round();

        final IconData volumeIcon = isMuted
            ? Icons.volume_off_rounded
            : volume < 0.5
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded;

        final tooltipMessage = l10n != null
            ? (isMuted
                ? l10n.volumeMutedTooltip
                : l10n.volumeTooltip(percent))
            : 'Volume: $percent%';

        return Tooltip(
          message: tooltipMessage,
          waitDuration: const Duration(milliseconds: 600),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _handleScroll(event, context, volume);
                }
              },
              child: Container(
                height: widget.height,
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream.withValues(
                    alpha: _isHovered ? 0.9 : 0.6,
                  ),
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  border: Border.all(
                    color: AppColors.bronzeIcon.withValues(
                      alpha: _isHovered ? 0.45 : 0.25,
                    ),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Mute / Unmute Button
                    GestureDetector(
                      onTap: () => context.read<AppVolumeCubit>().toggleMute(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          volumeIcon,
                          size: 14.5,
                          color: isMuted
                              ? AppColors.inkBrown.withValues(alpha: 0.4)
                              : AppColors.bronzeDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2.0),

                    // Slider
                    SizedBox(
                      width: widget.sliderWidth,
                      height: widget.height,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2.8,
                          activeTrackColor: isMuted
                              ? AppColors.inkBrown.withValues(alpha: 0.3)
                              : AppColors.accentGold,
                          inactiveTrackColor:
                              AppColors.bronzeIcon.withValues(alpha: 0.15),
                          thumbColor: isMuted
                              ? AppColors.inkBrown.withValues(alpha: 0.5)
                              : AppColors.accentGold,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 4.5,
                            pressedElevation: 1.0,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                          trackShape: const RectangularSliderTrackShape(),
                        ),
                        child: Slider(
                          value: volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) {
                            context.read<AppVolumeCubit>().setVolume(val);
                          },
                        ),
                      ),
                    ),

                    if (widget.showPercent) ...[
                      const SizedBox(width: 4.0),
                      SizedBox(
                        width: 26.0,
                        child: Text(
                          '$percent%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkBrown.withValues(alpha: 0.85),
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

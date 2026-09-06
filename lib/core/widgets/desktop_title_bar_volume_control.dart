import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/volume/app_volume_cubit.dart';
import '../bloc/volume/app_volume_state.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';

class DesktopTitleBarVolumeControl extends StatefulWidget {
  const DesktopTitleBarVolumeControl({super.key});

  @override
  State<DesktopTitleBarVolumeControl> createState() =>
      _DesktopTitleBarVolumeControlState();
}

class _DesktopTitleBarVolumeControlState
    extends State<DesktopTitleBarVolumeControl> {
  bool _isHovered = false;

  void _handleScroll(PointerScrollEvent event, BuildContext context, double currentVolume) {
    // Scroll up (negative delta) increases volume, scroll down decreases.
    final delta = event.scrollDelta.dy < 0 ? 0.05 : -0.05;
    final newVolume = (currentVolume + delta).clamp(0.0, 1.0);
    context.read<AppVolumeCubit>().setVolume(newVolume);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.select((SettingsBloc bloc) => bloc.state.effectiveMushafTheme);
    final isDark = theme.isDarkTheme;
    final goldColor = theme.goldColor;
    final textColor = theme.textColor;

    return BlocBuilder<AppVolumeCubit, AppVolumeState>(
      builder: (context, state) {
        final volume = state.volume;
        final isMuted = state.isMuted || volume == 0.0;
        final percent = (volume * 100).round();

        final IconData volumeIcon = isMuted
            ? Icons.volume_off_rounded
            : volume < 0.5
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _handleScroll(event, context, volume);
                }
              },
              child: Container(
                height: 24.0,
                margin: const EdgeInsets.symmetric(horizontal: 6.0),
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: _isHovered ? 0.08 : 0.04)
                      : Colors.black.withValues(alpha: _isHovered ? 0.07 : 0.035),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: goldColor.withValues(alpha: _isHovered ? 0.35 : 0.18),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Mute / Unmute Toggle Icon Button
                    GestureDetector(
                      onTap: () => context.read<AppVolumeCubit>().toggleMute(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          volumeIcon,
                          size: 14.5,
                          color: isMuted
                              ? textColor.withValues(alpha: 0.45)
                              : goldColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2.0),

                    // Micro Slider
                    _DesktopVolumeMicroSlider(
                      volume: volume,
                      isMuted: isMuted,
                      activeColor: isMuted
                          ? textColor.withValues(alpha: 0.35)
                          : goldColor,
                      inactiveColor: textColor.withValues(alpha: 0.14),
                      onChanged: (val) {
                        context.read<AppVolumeCubit>().setVolume(val);
                      },
                    ),
                    const SizedBox(width: 4.0),

                    // Percentage Text
                    SizedBox(
                      width: 28.0,
                      child: Text(
                        '$percent%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: textColor.withValues(alpha: 0.85),
                          height: 1.0,
                        ),
                      ),
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

class _DesktopVolumeMicroSlider extends StatelessWidget {
  final double volume;
  final bool isMuted;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double> onChanged;

  const _DesktopVolumeMicroSlider({
    required this.volume,
    required this.isMuted,
    required this.activeColor,
    required this.inactiveColor,
    required this.onChanged,
  });

  void _handlePointer(Offset localPosition, double width) {
    final newVolume = (localPosition.dx / width).clamp(0.0, 1.0);
    onChanged(newVolume);
  }

  @override
  Widget build(BuildContext context) {
    const width = 60.0;
    const height = 24.0;
    const thumbRadius = 4.5;
    const trackHeight = 3.0;

    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _handlePointer(details.localPosition, width),
        onHorizontalDragUpdate: (details) =>
            _handlePointer(details.localPosition, width),
        child: CustomPaint(
          size: const Size(width, height),
          painter: _DesktopVolumeSliderPainter(
            volume: volume,
            isMuted: isMuted,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            thumbRadius: thumbRadius,
            trackHeight: trackHeight,
          ),
        ),
      ),
    );
  }
}

class _DesktopVolumeSliderPainter extends CustomPainter {
  final double volume;
  final bool isMuted;
  final Color activeColor;
  final Color inactiveColor;
  final double thumbRadius;
  final double trackHeight;

  const _DesktopVolumeSliderPainter({
    required this.volume,
    required this.isMuted,
    required this.activeColor,
    required this.inactiveColor,
    required this.thumbRadius,
    required this.trackHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final trackRadius = trackHeight / 2;

    // 1. Inactive Track
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;
    final fullRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, centerY - trackRadius, size.width, trackHeight),
      Radius.circular(trackRadius),
    );
    canvas.drawRRect(fullRRect, inactivePaint);

    // 2. Active Track
    final activeWidth = size.width * volume;
    if (activeWidth > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;
      final activeRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - trackRadius, activeWidth, trackHeight),
        Radius.circular(trackRadius),
      );
      canvas.drawRRect(activeRRect, activePaint);
    }

    // 3. Thumb
    final thumbCenterX =
        (size.width * volume).clamp(thumbRadius, size.width - thumbRadius);
    final thumbCenter = Offset(thumbCenterX, centerY);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(
        thumbCenter + const Offset(0, 0.8), thumbRadius, shadowPaint);

    final thumbPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, thumbRadius, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _DesktopVolumeSliderPainter oldDelegate) {
    return oldDelegate.volume != volume ||
        oldDelegate.isMuted != isMuted ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

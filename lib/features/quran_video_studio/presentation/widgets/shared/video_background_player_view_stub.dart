import 'package:flutter/widgets.dart';

/// Non-web fallback stub for VideoBackgroundPlayerViewWeb.
class VideoBackgroundPlayerViewWeb extends StatelessWidget {
  final String videoPath;
  final bool isPlaying;
  final double dimming;
  final int resetSignal;
  final Duration? currentPosition;
  final int seekSignal;
  final Duration? seekPosition;

  const VideoBackgroundPlayerViewWeb({
    super.key,
    required this.videoPath,
    required this.isPlaying,
    this.dimming = 0.35,
    this.resetSignal = 0,
    this.currentPosition,
    this.seekSignal = 0,
    this.seekPosition,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

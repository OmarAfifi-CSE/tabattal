import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Lightweight, auto-looping, muted video player widget for previewing
/// custom background videos behind Quran recitation.
class VideoBackgroundPlayerView extends StatefulWidget {
  final String videoPath;
  final bool isPlaying;
  final double dimming;
  final int resetSignal;

  const VideoBackgroundPlayerView({
    super.key,
    required this.videoPath,
    required this.isPlaying,
    this.dimming = 0.35,
    this.resetSignal = 0,
  });

  @override
  State<VideoBackgroundPlayerView> createState() => _VideoBackgroundPlayerViewState();
}

class _VideoBackgroundPlayerViewState extends State<VideoBackgroundPlayerView> {
  VideoPlayerController? _controller;
  String? _initializedPath;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant VideoBackgroundPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _initPlayer();
    } else {
      if (oldWidget.resetSignal != widget.resetSignal &&
          _controller != null &&
          _controller!.value.isInitialized) {
        _controller?.seekTo(Duration.zero);
      }
      if (oldWidget.isPlaying != widget.isPlaying &&
          _controller != null &&
          _controller!.value.isInitialized) {
        if (widget.isPlaying) {
          _controller?.play();
        } else {
          _controller?.pause();
        }
      }
    }
  }

  Future<void> _initPlayer() async {
    final path = widget.videoPath;
    if (_initializedPath == path && _controller != null) return;
    if (path.trim().isEmpty) return;

    final isWebOrUrl = kIsWeb ||
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:');

    if (!isWebOrUrl) {
      final file = File(path);
      if (!file.existsSync()) return;
    }

    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final newController = isWebOrUrl
        ? VideoPlayerController.networkUrl(
            Uri.parse(path),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.file(
            File(path),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
    _initializedPath = path;

    try {
      await newController.initialize();
      await newController.setLooping(true);
      await newController.setVolume(0.0); // Mute completely to protect Quran audio

      if (!mounted) {
        await newController.dispose();
        return;
      }

      setState(() {
        _controller = newController;
      });

      if (widget.isPlaying) {
        await newController.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _controller = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null && controller.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          )
        else
          Container(
            color: const Color(0xFF0F141C),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFD4AF37),
                ),
              ),
            ),
          ),

        // Dimming overlay
        Container(
          color: Colors.black.withValues(alpha: widget.dimming.clamp(0.0, 0.95)),
        ),
      ],
    );
  }
}

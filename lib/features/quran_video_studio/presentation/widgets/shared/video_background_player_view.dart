import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'video_background_player_platform.dart';

/// Lightweight, auto-looping, muted video player widget for previewing
/// custom background videos behind Quran recitation.
class VideoBackgroundPlayerView extends StatefulWidget {
  final String videoPath;
  final bool isPlaying;
  final double dimming;
  final int resetSignal;
  final Duration? currentPosition;
  final int seekSignal;
  final Duration? seekPosition;

  const VideoBackgroundPlayerView({
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
  State<VideoBackgroundPlayerView> createState() => _VideoBackgroundPlayerViewState();
}

class _VideoBackgroundPlayerViewState extends State<VideoBackgroundPlayerView> {
  VideoPlayerController? _controller;
  String? _initializedPath;
  // Generation counter: incremented on every new _initPlayer() call.
  // Any async completion that sees a stale generation is silently dropped.
  int _initGeneration = 0;
  bool _isSeeking = false;
  bool _hasError = false;
  Duration? _pendingSeekTarget;

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
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        if (oldWidget.resetSignal != widget.resetSignal) {
          _performCoalescedSeek(Duration.zero);
        } else if (oldWidget.seekSignal != widget.seekSignal && widget.seekPosition != null) {
          final videoDuration = controller.value.duration;
          if (videoDuration > Duration.zero) {
            final targetMs = widget.seekPosition!.inMilliseconds % videoDuration.inMilliseconds;
            _performCoalescedSeek(Duration(milliseconds: targetMs));
          }
        }

        if (oldWidget.isPlaying != widget.isPlaying) {
          if (widget.isPlaying) {
            if (!_isSeeking) {
              controller.play();
            }
          } else {
            controller.pause();
          }
        }
      }
    }
  }

  void _performCoalescedSeek(Duration target) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (_isSeeking) {
      _pendingSeekTarget = target;
      return;
    }

    _isSeeking = true;
    _pendingSeekTarget = null;

    controller.seekTo(target).then((_) {
      // Completed successfully
    }).catchError((_) {
      // Ignore seek exceptions during disposal or out-of-bounds
    }).whenComplete(() {
      if (!mounted) return;
      _isSeeking = false;
      final pending = _pendingSeekTarget;
      if (pending != null) {
        _performCoalescedSeek(pending);
      } else {
        if (widget.isPlaying) {
          controller.play();
        } else {
          controller.pause();
        }
      }
    });
  }

  void _initPlayer() {
    final path = widget.videoPath;
    if (_initializedPath == path && _controller != null && !_hasError) return;
    if (path.trim().isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    // Bump the generation so any in-flight init from a previous path is ignored.
    final generation = ++_initGeneration;
    _hasError = false;
    _initializedPath = path;

    // Detach and dispose the old controller WITHOUT awaiting — fire-and-forget
    // so the main thread is never stalled by native teardown on Windows.
    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      unawaited(oldController.dispose());
    }

    // Show loading spinner immediately, without waiting for initialize().
    if (mounted) setState(() {});

    _initAsync(path, generation);
  }

  Future<void> _initAsync(String path, int generation) async {
    final isWebOrUrl = kIsWeb ||
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('blob:');

    final normalizedPath = isWebOrUrl ? path : p.normalize(path);

    if (!isWebOrUrl) {
      final file = File(normalizedPath);
      if (!file.existsSync()) {
        if (mounted && generation == _initGeneration) {
          setState(() => _hasError = true);
        }
        return;
      }
    }

    final newController = isWebOrUrl
        ? VideoPlayerController.networkUrl(
            Uri.parse(normalizedPath),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.file(
            File(normalizedPath),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );

    try {
      await newController.initialize();
      await newController.setLooping(true);
      await newController.setVolume(0.0);

      // Apply timeline position right away (e.g. opening fullscreen mid-preview).
      try {
        final initialSeek = widget.seekPosition ?? widget.currentPosition;
        if (initialSeek != null && initialSeek > Duration.zero) {
          final videoDuration = newController.value.duration;
          if (videoDuration > Duration.zero) {
            await newController.seekTo(Duration(
              milliseconds: initialSeek.inMilliseconds % videoDuration.inMilliseconds,
            ));
          }
        }
      } catch (_) {}

      // Stale generation or widget unmounted — discard safely.
      if (!mounted || generation != _initGeneration) {
        unawaited(newController.dispose());
        return;
      }

      setState(() {
        _controller = newController;
        _hasError = false;
      });

      if (widget.isPlaying) {
        unawaited(newController.play());
      }
    } catch (_) {
      unawaited(newController.dispose());
      if (mounted && generation == _initGeneration) {
        setState(() {
          _controller = null;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _isSeeking = false;
    _pendingSeekTarget = null;
    // Increment generation to invalidate any in-flight _initAsync.
    _initGeneration++;
    // Fire-and-forget: no await on dispose to keep Flutter's widget teardown fast.
    final c = _controller;
    _controller = null;
    if (c != null) unawaited(c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return VideoBackgroundPlayerViewWeb(
        key: ValueKey('web_video_bg_${widget.videoPath}'),
        videoPath: widget.videoPath,
        isPlaying: widget.isPlaying,
        dimming: widget.dimming,
        resetSignal: widget.resetSignal,
        currentPosition: widget.currentPosition,
        seekSignal: widget.seekSignal,
        seekPosition: widget.seekPosition,
      );
    }

    final controller = _controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null &&
            controller.value.isInitialized &&
            controller.value.size.width > 0 &&
            controller.value.size.height > 0)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          )
        else if (_hasError)
          Container(
            color: const Color(0xFF0F141C),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        Localizations.maybeLocaleOf(context)?.languageCode == 'en'
                            ? 'Unable to play the selected video file.'
                            : 'تعذر تشغيل ملف الفيديو المحدد.',
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
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

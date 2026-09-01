import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../../../../core/theme/app_colors.dart';

/// High-performance Web video background player that renders a native HTML5 `<video>`
/// element within a Flutter Web platform view for seamless 60/120 FPS playback.
class VideoBackgroundPlayerViewWeb extends StatefulWidget {
  final String videoPath;
  final bool isPlaying;
  final double dimming;
  final int resetSignal;
  final Duration? currentPosition;

  const VideoBackgroundPlayerViewWeb({
    super.key,
    required this.videoPath,
    required this.isPlaying,
    this.dimming = 0.35,
    this.resetSignal = 0,
    this.currentPosition,
  });

  @override
  State<VideoBackgroundPlayerViewWeb> createState() =>
      _VideoBackgroundPlayerViewWebState();
}

class _VideoBackgroundPlayerViewWebState
    extends State<VideoBackgroundPlayerViewWeb> {
  web.HTMLVideoElement? _videoElement;
  bool _isVideoReady = false;
  bool _hasError = false;

  void _configureVideo(web.HTMLVideoElement video) {
    _videoElement = video;
    video
      ..muted = true
      ..defaultMuted = true
      ..loop = true
      ..volume = 0
      ..controls = false
      ..preload = 'auto'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..setAttribute('muted', 'true')
      ..setAttribute('loop', 'true')
      ..src = widget.videoPath
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.display = 'block'
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.left = '0'
      ..style.border = 'none'
      ..style.outline = 'none'
      ..style.backgroundColor = 'transparent'
      ..style.direction = 'ltr';

    // Prevent Flutter Web RTL platform-view positioning bug by ensuring LTR on parents and slots
    void alignSlots() {
      try {
        web.Element? curr = video.parentElement;
        while (curr != null) {
          if (curr.isA<web.HTMLElement>()) {
            (curr as web.HTMLElement).style.direction = 'ltr';
          }
          curr = curr.parentElement;
        }

        final glassPane = web.document.querySelector('flt-glass-pane');
        if (glassPane != null) {
          final shadow = glassPane.shadowRoot;
          if (shadow != null) {
            final slots = shadow.querySelectorAll('flt-platform-view-slot');
            for (var i = 0; i < slots.length; i++) {
              final slot = slots.item(i);
              if (slot != null && slot.isA<web.HTMLElement>()) {
                final htmlSlot = slot as web.HTMLElement;
                htmlSlot.style.left = '0px';
                htmlSlot.style.direction = 'ltr';
              }
            }
          }
        }
      } catch (_) {}
    }

    alignSlots();

    void syncPlayback() {
      alignSlots();
      if (widget.isPlaying) {
        try {
          video.play();
        } catch (_) {}
      } else {
        try {
          video.pause();
        } catch (_) {}
      }
    }

    video.onloadedmetadata = ((web.Event _) {
      try {
        if (video.currentTime == 0) {
          video.currentTime = 0.001;
        }
      } catch (_) {}
      if (mounted && !_isVideoReady) {
        setState(() => _isVideoReady = true);
      }
      syncPlayback();
    }).toJS;

    video.onloadeddata = ((web.Event _) {
      if (mounted && !_isVideoReady) {
        setState(() => _isVideoReady = true);
      }
      syncPlayback();
    }).toJS;

    video.oncanplay = ((web.Event _) {
      if (mounted && !_isVideoReady) {
        setState(() => _isVideoReady = true);
      }
      syncPlayback();
    }).toJS;

    video.onerror = ((web.Event _) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isVideoReady = false;
        });
      }
    }).toJS;

    try {
      video.load();
      syncPlayback();
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant VideoBackgroundPlayerViewWeb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_videoElement != null) {
      if (oldWidget.videoPath != widget.videoPath) {
        setState(() => _isVideoReady = false);
        _videoElement!.src = widget.videoPath;
        _videoElement!.load();
        if (widget.isPlaying) {
          _videoElement!.play();
        } else {
          _videoElement!.currentTime = 0.001;
          _videoElement!.pause();
        }
      }

      if (oldWidget.isPlaying != widget.isPlaying) {
        if (widget.isPlaying) {
          try {
            _videoElement!.play();
          } catch (_) {}
        } else {
          try {
            _videoElement!.pause();
          } catch (_) {}
        }
      }

      if (oldWidget.resetSignal != widget.resetSignal) {
        _videoElement!.currentTime = 0.001;
        if (widget.isPlaying) {
          try {
            _videoElement!.play();
          } catch (_) {}
        } else {
          try {
            _videoElement!.pause();
          } catch (_) {}
        }
      } else if (widget.currentPosition != null &&
          oldWidget.currentPosition != widget.currentPosition) {
        final videoDuration = _videoElement!.duration;
        if (!videoDuration.isNaN && videoDuration > 0) {
          final targetSec = (widget.currentPosition!.inMilliseconds / 1000.0) % videoDuration;
          final diffSec = (_videoElement!.currentTime - targetSec).abs();
          if (!widget.isPlaying || diffSec > 0.35) {
            _videoElement!.currentTime = targetSec;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    try {
      _videoElement?.pause();
      _videoElement?.src = '';
    } catch (_) {}
    _videoElement = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: _isVideoReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HtmlElementView.fromTagName(
                  tagName: 'video',
                  onElementCreated: (Object element) {
                    if (element.isA<web.HTMLVideoElement>()) {
                      _configureVideo(element as web.HTMLVideoElement);
                    }
                  },
                ),
                // Dimming overlay directly over the video stream
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: widget.dimming.clamp(0.0, 0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_isVideoReady && !_hasError)
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.35),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.20),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ),
          if (_hasError)
            Center(
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
                        'تعذر تشغيل الفيديو من هذا الرابط، يرجى التأكد من أنه رابط مباشر (MP4).',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontFamily: 'Amiri',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

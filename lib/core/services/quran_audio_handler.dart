import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

enum QuranAudioAction { nextAyah, prevAyah, nextSurah, prevSurah, timer, stop }

class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  final _actionSubject = StreamController<QuranAudioAction>.broadcast();

  static const _previousSurahControl = MediaControl(
    androidIcon: 'drawable/ic_media_rewind',
    label: 'Previous Surah',
    action: MediaAction.rewind,
  );
  static const _previousControl = MediaControl(
    androidIcon: 'drawable/ic_media_previous',
    label: 'Previous',
    action: MediaAction.skipToPrevious,
  );
  static const _playControl = MediaControl(
    androidIcon: 'drawable/ic_media_play',
    label: 'Play',
    action: MediaAction.play,
  );
  static const _pauseControl = MediaControl(
    androidIcon: 'drawable/ic_media_pause',
    label: 'Pause',
    action: MediaAction.pause,
  );
  static const _nextControl = MediaControl(
    androidIcon: 'drawable/ic_media_next',
    label: 'Next',
    action: MediaAction.skipToNext,
  );
  static const _nextSurahControl = MediaControl(
    androidIcon: 'drawable/ic_media_fast_forward',
    label: 'Next Surah',
    action: MediaAction.fastForward,
  );
  static const _stopControl = MediaControl(
    androidIcon: 'drawable/ic_media_stop',
    label: 'Stop',
    action: MediaAction.stop,
  );

  AudioPlayer _player = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 3),
        maxBufferDuration: Duration(seconds: 30),
        bufferForPlaybackDuration: Duration(milliseconds: 1000),
        bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 1500),
        prioritizeTimeOverSizeThresholds: true,
        backBufferDuration: Duration(seconds: 2),
      ),
      darwinLoadControl: DarwinLoadControl(
        automaticallyWaitsToMinimizeStalling: true,
      ),
    ),
    androidAudioOffloadPreferences: const AndroidAudioOffloadPreferences(
      audioOffloadMode: AndroidAudioOffloadMode.disabled,
    ),
  );
  StreamSubscription? _playbackSubscription;
  StreamSubscription? _durationSubscription;

  Stream<QuranAudioAction> get actions => _actionSubject.stream;
  AudioPlayer get player => _player;

  QuranAudioHandler() {
    _bindPlayerStreams();
  }

  void _bindPlayerStreams() {
    _playbackSubscription?.cancel();
    _durationSubscription?.cancel();

    _playbackSubscription = _player.playbackEventStream.map(_transformEvent).listen(
      (state) {
        if (!playbackState.isClosed) {
          playbackState.add(state);
        }
      },
      onError: (_) {},
    );

    _durationSubscription = _player.durationStream.listen(
      (duration) {
        final currentItem = mediaItem.valueOrNull;
        if (currentItem != null && duration != null) {
          mediaItem.add(currentItem.copyWith(duration: duration));
        }
      },
      onError: (_) {},
    );
  }

  /// Rebinds media transport controls and notification state to a new active AudioPlayer
  /// during seamless Ping-Pong handoff.
  void switchPlayer(AudioPlayer newPlayer) {
    if (_player == newPlayer) return;
    _player = newPlayer;
    _bindPlayerStreams();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        _previousSurahControl,
        _previousControl, // Previous Ayah
        if (_player.playing) _pauseControl else _playControl,
        _nextControl, // Next Ayah
        _nextSurahControl,
        _stopControl,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [1, 2, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[event.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      updateTime: event.updateTime,
    );
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.idle) return;
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  bool _isStopping = false;

  @override
  Future<void> stop() async {
    if (_isStopping) return;
    _isStopping = true;
    try {
      _actionSubject.add(QuranAudioAction.stop);
      mediaItem.add(null);
      playbackState.add(
        PlaybackState(
          controls: const [],
          systemActions: const {},
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      try {
        await _player.stop();
      } catch (_) {}
      await super.stop();
    } finally {
      _isStopping = false;
    }
  }

  /// Displays an offline/stopped notification informing the user where playback stopped.
  Future<void> showStoppedNotification({
    required String title,
    required String subtitle,
  }) async {
    await _player.stop();
    final artUri = mediaItem.valueOrNull?.artUri;
    mediaItem.add(
      MediaItem(
        id: 'stopped_offline',
        title: title,
        artist: subtitle,
        artUri: artUri,
      ),
    );
    playbackState.add(
      PlaybackState(
        controls: const [_stopControl],
        systemActions: const {},
        processingState: AudioProcessingState.completed,
        playing: false,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    _actionSubject.add(QuranAudioAction.nextAyah);
  }

  @override
  Future<void> skipToPrevious() async {
    _actionSubject.add(QuranAudioAction.prevAyah);
  }

  @override
  Future<void> fastForward() async {
    _actionSubject.add(QuranAudioAction.nextSurah);
  }

  @override
  Future<void> rewind() async {
    _actionSubject.add(QuranAudioAction.prevSurah);
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'timer') {
      _actionSubject.add(QuranAudioAction.timer);
    }
  }

  Future<void> updateItem(MediaItem item) async {
    try {
      mediaItem.add(item);
    } catch (_) {}
  }
}

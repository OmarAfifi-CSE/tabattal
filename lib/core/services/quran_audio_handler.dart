import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

enum QuranAudioAction {
  nextAyah,
  prevAyah,
  nextSurah,
  prevSurah,
  timer,
  stop,
}

class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final _actionSubject = StreamController<QuranAudioAction>.broadcast();

  Stream<QuranAudioAction> get actions => _actionSubject.stream;
  AudioPlayer get player => _player;

  QuranAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).listen((state) {
      if (!playbackState.isClosed) {
        playbackState.add(state);
      }
    });

    _player.durationStream.listen((duration) {
      final currentItem = mediaItem.valueOrNull;
      if (currentItem != null && duration != null) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind, // Previous Surah
        MediaControl.skipToPrevious, // Previous Ayah
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext, // Next Ayah
        MediaControl.fastForward, // Next Surah
        MediaControl.stop,
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
      }[_player.processingState]!,
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
    _actionSubject.add(QuranAudioAction.stop);
    await _player.stop();
    await super.stop();
    _isStopping = false;
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
    mediaItem.add(item);
  }
}

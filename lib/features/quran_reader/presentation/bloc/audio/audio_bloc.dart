import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'audio_event.dart';
import 'audio_state.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  final AudioPlayer _audioPlayer;
  List<int> _currentVerseIds = [];
  int _currentIndex = 0;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _currentIndexSubscription;
  StreamSubscription? _playbackEventSubscription;

  AudioBloc() : _audioPlayer = AudioPlayer(), super(AudioIdle()) {
    on<PlayVerse>(_onPlayVerse, transformer: restartable());
    on<PlayPlaylist>(_onPlayPlaylist, transformer: restartable());
    on<PauseAudio>(_onPauseAudio);
    on<ResumeAudio>(_onResumeAudio);
    on<StopAudio>(_onStopAudio);
    on<AudioStateChanged>(_onStateChanged);
    on<AudioErrorEvent>((event, emit) => emit(AudioError(event.message)));

    _initStreams();
  }

  void _initStreams() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        add(const AudioStateChanged(isPlaying: false));
      } else {
        add(AudioStateChanged(isPlaying: state.playing));
      }
    });

    _currentIndexSubscription = _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && _currentVerseIds.isNotEmpty && index < _currentVerseIds.length) {
        _currentIndex = index;
        add(AudioStateChanged(isPlaying: _audioPlayer.playing));
      }
    });

    _playbackEventSubscription = _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        if (e is PlayerException) {
          add(const AudioStateChanged(isPlaying: false));
          add(const AudioErrorEvent("Network error: Check connection to stream audio."));
        } else {
          add(const AudioStateChanged(isPlaying: false));
          add(const AudioErrorEvent("Failed to play audio."));
        }
      },
    );
  }

  Future<void> _onPlayVerse(PlayVerse event, Emitter<AudioState> emit) async {
    emit(AudioLoading());
    try {
      _currentVerseIds = [event.verseId];
      _currentIndex = 0;
      await _audioPlayer.setUrl(event.audioUrl);
      _audioPlayer.play();
      emit(AudioPlaying(event.verseId));
    } on PlayerException catch (e) {
      emit(AudioError("Player error: ${e.message}"));
    } on PlayerInterruptedException catch (e) {
      // This happens when setUrl is called again while it's still buffering (i.e., we are restarting)
      emit(const AudioError("Audio stream interrupted."));
    } catch (e) {
      emit(AudioError("Error playing audio."));
    }
  }

  Future<void> _onPlayPlaylist(PlayPlaylist event, Emitter<AudioState> emit) async {
    emit(AudioLoading());
    try {
      _currentVerseIds = event.verseIds;
      _currentIndex = event.startIndex;

      final playlist = event.audioUrls.map((url) => AudioSource.uri(Uri.parse(url))).toList();

      await _audioPlayer.setAudioSource(ConcatenatingAudioSource(children: playlist), initialIndex: event.startIndex);
      _audioPlayer.play();
      emit(AudioPlaying(_currentVerseIds[_currentIndex]));
    } catch (e) {
      emit(AudioError("Error loading playlist."));
    }
  }

  Future<void> _onPauseAudio(PauseAudio event, Emitter<AudioState> emit) async {
    await _audioPlayer.pause();
    if (_currentVerseIds.isNotEmpty) {
      emit(AudioPaused(_currentVerseIds[_currentIndex]));
    } else {
      emit(AudioIdle());
    }
  }

  Future<void> _onResumeAudio(ResumeAudio event, Emitter<AudioState> emit) async {
    _audioPlayer.play();
    if (_currentVerseIds.isNotEmpty) {
      emit(AudioPlaying(_currentVerseIds[_currentIndex]));
    }
  }

  Future<void> _onStopAudio(StopAudio event, Emitter<AudioState> emit) async {
    await _audioPlayer.stop();
    _currentVerseIds = [];
    _currentIndex = 0;
    emit(AudioIdle());
  }

  void _onStateChanged(AudioStateChanged event, Emitter<AudioState> emit) {
    if (_currentVerseIds.isEmpty) return;
    
    final verseId = _currentVerseIds[_currentIndex];
    if (event.isPlaying) {
      emit(AudioPlaying(verseId));
    } else {
      if (_audioPlayer.processingState == ProcessingState.completed) {
        emit(AudioIdle());
      } else {
        emit(AudioPaused(verseId));
      }
    }
  }

  @override
  Future<void> close() {
    _playerStateSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _playbackEventSubscription?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}

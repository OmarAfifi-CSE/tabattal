import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../../../../core/network/audio_download_manager.dart';
import 'audio_event.dart';
import 'audio_state.dart';

class AudioBloc extends Bloc<AudioEvent, AudioState> {
  final AudioPlayer _audioPlayer;
  final AudioDownloadManager _downloadManager;
  List<int> _currentVerseIds = [];
  int _currentIndex = 0;
  String _currentReciter = 'مشاري العفاسي'; // Arabic default
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _currentIndexSubscription;
  StreamSubscription? _playbackEventSubscription;

  String get currentReciter => _currentReciter;

  AudioBloc(this._downloadManager) : _audioPlayer = AudioPlayer(), super(AudioIdle()) {
    on<PlayVerse>(_onPlayVerse, transformer: restartable());
    on<PlayPlaylist>(_onPlayPlaylist, transformer: restartable());
    on<PauseAudio>(_onPauseAudio);
    on<ResumeAudio>(_onResumeAudio);
    on<StopAudio>(_onStopAudio);
    on<AudioStateChanged>(_onStateChanged);
    on<ChangeReciter>(_onChangeReciter);
    on<AudioErrorEvent>((event, emit) => emit(AudioError(event.message)));

    _initStreams();
  }

  void _initStreams() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Auto-advance logic:
        if (_currentVerseIds.isNotEmpty) {
          final currentVerseId = _currentVerseIds.last; // Using last or first since it's a single verse playback usually
          final nextVerseId = currentVerseId + 1; // Assuming sequential IDs (e.g., 1001 -> 1002).
          
          // Trigger playback for the next verse seamlessly
          add(PlayVerse('', nextVerseId)); // AudioUrl is dynamically constructed now
        } else {
          add(const AudioStateChanged(isPlaying: false));
        }
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
      
      final surah = event.verseId ~/ 1000;
      final ayah = event.verseId % 1000;

      final localPath = await _downloadManager.getLocalVersePath(_currentReciter, event.verseId);
      
      // Fallback to checking assets if not in app documents directory
      if (localPath != null) {
        await _audioPlayer.setFilePath(localPath);
      } else if (event.audioUrl.startsWith('assets/')) {
        try {
          await _audioPlayer.setAsset(event.audioUrl);
        } catch (e) {
          // If asset fails, stream it
          final url = _downloadManager.getStreamingUrl(_currentReciter, surah, ayah);
          await _audioPlayer.setUrl(url);
        }
      } else {
        // Stream it online
        final url = _downloadManager.getStreamingUrl(_currentReciter, surah, ayah);
        await _audioPlayer.setUrl(url);
      }
      
      _audioPlayer.play();
      emit(AudioPlaying(event.verseId));

      // Trigger predictive pre-fetching for gapless playback
      _downloadManager.prefetchVerses(_currentReciter, surah, ayah);

    } on PlayerException catch (_) {
      emit(const AudioError("الملف الصوتي غير متوفر (يجب التحميل أو الاتصال بالإنترنت)."));
    } on PlayerInterruptedException catch (_) {
      // This happens when setUrl is called again while it's still buffering (i.e., we are restarting)
      emit(const AudioError("Audio stream interrupted."));
    } catch (_) {
      emit(const AudioError("حدث خطأ أثناء تشغيل التلاوة. الرجاء تحميل الملفات الصوتية."));
    }
  }

  Future<void> _onPlayPlaylist(PlayPlaylist event, Emitter<AudioState> emit) async {
    emit(AudioLoading());
    try {
      _currentVerseIds = event.verseIds;
      _currentIndex = event.startIndex;

      // Parsing as local files instead of remote URIs
      final playlist = event.audioUrls.map((path) => AudioSource.file(path)).toList();

      // ignore: deprecated_member_use
      await _audioPlayer.setAudioSource(ConcatenatingAudioSource(children: playlist), initialIndex: event.startIndex);
      _audioPlayer.play();
      emit(AudioPlaying(_currentVerseIds[_currentIndex]));
    } catch (_) {
      emit(const AudioError("Error loading playlist."));
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

  void _onChangeReciter(ChangeReciter event, Emitter<AudioState> emit) {
    _currentReciter = event.reciterName;
    // If currently playing, we might want to restart the current verse with the new reciter.
    if (state is AudioPlaying || state is AudioPaused) {
      if (_currentVerseIds.isNotEmpty) {
        add(PlayVerse('', _currentVerseIds[_currentIndex]));
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

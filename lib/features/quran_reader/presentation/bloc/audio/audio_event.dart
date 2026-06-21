import 'package:equatable/equatable.dart';

abstract class AudioEvent extends Equatable {
  const AudioEvent();

  @override
  List<Object> get props => [];
}

class PlayVerse extends AudioEvent {
  final String audioUrl;
  final int verseId; // Used for highlighting

  const PlayVerse(this.audioUrl, this.verseId);

  @override
  List<Object> get props => [audioUrl, verseId];
}

class PlayPlaylist extends AudioEvent {
  final List<String> audioUrls;
  final List<int> verseIds;
  final int startIndex;

  const PlayPlaylist({
    required this.audioUrls,
    required this.verseIds,
    this.startIndex = 0,
  });

  @override
  List<Object> get props => [audioUrls, verseIds, startIndex];
}

class PauseAudio extends AudioEvent {}

class ResumeAudio extends AudioEvent {}

class StopAudio extends AudioEvent {}

// Internal event for state updates from player stream
class AudioStateChanged extends AudioEvent {
  final int? currentVerseId;
  final bool isPlaying;

  const AudioStateChanged({this.currentVerseId, required this.isPlaying});

  @override
  List<Object> get props => [currentVerseId ?? -1, isPlaying];
}

class AudioErrorEvent extends AudioEvent {
  final String message;

  const AudioErrorEvent(this.message);

  @override
  List<Object> get props => [message];
}

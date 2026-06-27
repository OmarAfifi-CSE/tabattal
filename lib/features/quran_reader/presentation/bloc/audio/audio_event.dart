import 'package:equatable/equatable.dart';

abstract class AudioEvent extends Equatable {
  const AudioEvent();

  @override
  List<Object> get props => [];
}

class PlayVerse extends AudioEvent {
  final String audioUrl;
  final int verseId; // Used for highlighting
  final bool skipBasmalah;

  const PlayVerse(this.audioUrl, this.verseId, {this.skipBasmalah = false});

  @override
  List<Object> get props => [audioUrl, verseId, skipBasmalah];
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

class PauseAudio extends AudioEvent {
  const PauseAudio();
}

class ResumeAudio extends AudioEvent {
  const ResumeAudio();
}

class StopAudio extends AudioEvent {
  const StopAudio();
}

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

class ChangeReciter extends AudioEvent {
  final String reciterName;

  const ChangeReciter(this.reciterName);

  @override
  List<Object> get props => [reciterName];
}

class ChangeRepeatCount extends AudioEvent {
  final int repeatCount;
  const ChangeRepeatCount(this.repeatCount);
  @override
  List<Object> get props => [repeatCount];
}

class SetSleepTimer extends AudioEvent {
  final Duration duration;
  const SetSleepTimer(this.duration);
  @override
  List<Object> get props => [duration];
}

class CancelSleepTimer extends AudioEvent {
  const CancelSleepTimer();
  @override
  List<Object> get props => [];
}

class NextAyah extends AudioEvent {
  const NextAyah();
}

class PreviousAyah extends AudioEvent {
  const PreviousAyah();
}

class NextSurah extends AudioEvent {
  const NextSurah();
}

class PreviousSurah extends AudioEvent {
  const PreviousSurah();
}

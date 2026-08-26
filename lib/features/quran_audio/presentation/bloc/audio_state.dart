import 'package:equatable/equatable.dart';

abstract class AudioState extends Equatable {
  const AudioState();

  @override
  List<Object?> get props => [];
}

class AudioIdle extends AudioState {}

class AudioLoading extends AudioState {}

class AudioPlaying extends AudioState {
  final int currentVerseId;

  const AudioPlaying(this.currentVerseId);

  @override
  List<Object> get props => [currentVerseId];
}

class AudioPaused extends AudioState {
  final int currentVerseId;

  const AudioPaused(this.currentVerseId);

  @override
  List<Object> get props => [currentVerseId];
}

class AudioError extends AudioState {
  final String message;

  const AudioError(this.message);

  @override
  List<Object> get props => [message];
}

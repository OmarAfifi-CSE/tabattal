import 'package:equatable/equatable.dart';

enum HifzMaskingType {
  fullVerse,
  verseTail,
  wordByWord,
}

abstract class HifzEvent extends Equatable {
  const HifzEvent();

  @override
  List<Object?> get props => [];
}

class ToggleHifzMode extends HifzEvent {
  final bool? enabled;
  const ToggleHifzMode({this.enabled});

  @override
  List<Object?> get props => [enabled];
}

class SetHifzMaskingType extends HifzEvent {
  final HifzMaskingType maskingType;
  const SetHifzMaskingType(this.maskingType);

  @override
  List<Object?> get props => [maskingType];
}

class ToggleVerseReveal extends HifzEvent {
  final String verseKey;
  const ToggleVerseReveal(this.verseKey);

  @override
  List<Object?> get props => [verseKey];
}

class ToggleWordReveal extends HifzEvent {
  final String wordKey; // e.g. "1:1:1"
  const ToggleWordReveal(this.wordKey);

  @override
  List<Object?> get props => [wordKey];
}

class ClearRevealedItems extends HifzEvent {
  const ClearRevealedItems();
}

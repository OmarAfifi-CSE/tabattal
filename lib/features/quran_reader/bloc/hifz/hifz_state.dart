import 'package:equatable/equatable.dart';
import 'hifz_event.dart';

class HifzState extends Equatable {
  final bool isHifzModeActive;
  final HifzMaskingType maskingType;
  final Set<String> revealedVerseKeys;
  final Set<String> revealedWordKeys;

  const HifzState({
    this.isHifzModeActive = false,
    this.maskingType = HifzMaskingType.fullVerse,
    this.revealedVerseKeys = const {},
    this.revealedWordKeys = const {},
  });

  HifzState copyWith({
    bool? isHifzModeActive,
    HifzMaskingType? maskingType,
    Set<String>? revealedVerseKeys,
    Set<String>? revealedWordKeys,
  }) {
    return HifzState(
      isHifzModeActive: isHifzModeActive ?? this.isHifzModeActive,
      maskingType: maskingType ?? this.maskingType,
      revealedVerseKeys: revealedVerseKeys ?? this.revealedVerseKeys,
      revealedWordKeys: revealedWordKeys ?? this.revealedWordKeys,
    );
  }

  @override
  List<Object?> get props => [
        isHifzModeActive,
        maskingType,
        revealedVerseKeys,
        revealedWordKeys,
      ];
}

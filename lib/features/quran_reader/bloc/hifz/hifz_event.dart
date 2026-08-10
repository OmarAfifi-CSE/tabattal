import 'package:equatable/equatable.dart';
import '../../data/models/hifz_plan_model.dart';

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

class LoadHifzData extends HifzEvent {
  const LoadHifzData();
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

class UpdateVerseHifzStatus extends HifzEvent {
  final String verseKey;
  final int surahNumber;
  final int ayahNumber;
  final int pageNumber;
  final HifzItemStatus status;

  const UpdateVerseHifzStatus({
    required this.verseKey,
    required this.surahNumber,
    required this.ayahNumber,
    required this.pageNumber,
    required this.status,
  });

  @override
  List<Object?> get props => [verseKey, surahNumber, ayahNumber, pageNumber, status];
}

class CreateHifzPlanEvent extends HifzEvent {
  final String title;
  final int surahNumber;
  final int startPage;
  final int endPage;
  final int targetVersesCount;

  const CreateHifzPlanEvent({
    required this.title,
    required this.surahNumber,
    required this.startPage,
    required this.endPage,
    required this.targetVersesCount,
  });

  @override
  List<Object?> get props => [title, surahNumber, startPage, endPage, targetVersesCount];
}

class DeleteHifzPlanEvent extends HifzEvent {
  final int planId;
  const DeleteHifzPlanEvent(this.planId);

  @override
  List<Object?> get props => [planId];
}

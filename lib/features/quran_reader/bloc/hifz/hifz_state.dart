import 'package:equatable/equatable.dart';
import '../../data/models/hifz_plan_model.dart';
import 'hifz_event.dart';

class HifzState extends Equatable {
  final bool isHifzModeActive;
  final HifzMaskingType maskingType;
  final Set<String> revealedVerseKeys;
  final Set<String> revealedWordKeys;
  final List<HifzPlanModel> plans;
  final Map<String, HifzItemModel> hifzItems;
  final bool isLoading;

  const HifzState({
    this.isHifzModeActive = false,
    this.maskingType = HifzMaskingType.fullVerse,
    this.revealedVerseKeys = const {},
    this.revealedWordKeys = const {},
    this.plans = const [],
    this.hifzItems = const {},
    this.isLoading = false,
  });

  HifzState copyWith({
    bool? isHifzModeActive,
    HifzMaskingType? maskingType,
    Set<String>? revealedVerseKeys,
    Set<String>? revealedWordKeys,
    List<HifzPlanModel>? plans,
    Map<String, HifzItemModel>? hifzItems,
    bool? isLoading,
  }) {
    return HifzState(
      isHifzModeActive: isHifzModeActive ?? this.isHifzModeActive,
      maskingType: maskingType ?? this.maskingType,
      revealedVerseKeys: revealedVerseKeys ?? this.revealedVerseKeys,
      revealedWordKeys: revealedWordKeys ?? this.revealedWordKeys,
      plans: plans ?? this.plans,
      hifzItems: hifzItems ?? this.hifzItems,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        isHifzModeActive,
        maskingType,
        revealedVerseKeys,
        revealedWordKeys,
        plans,
        hifzItems,
        isLoading,
      ];
}

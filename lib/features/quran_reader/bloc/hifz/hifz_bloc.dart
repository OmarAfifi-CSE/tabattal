import 'package:flutter_bloc/flutter_bloc.dart';
import 'hifz_event.dart';
import 'hifz_state.dart';

class HifzBloc extends Bloc<HifzEvent, HifzState> {
  HifzBloc() : super(const HifzState()) {
    on<ToggleHifzMode>(_onToggleHifzMode);
    on<SetHifzMaskingType>(_onSetHifzMaskingType);
    on<ToggleVerseReveal>(_onToggleVerseReveal);
    on<ToggleWordReveal>(_onToggleWordReveal);
    on<ClearRevealedItems>(_onClearRevealedItems);
  }

  void _onToggleHifzMode(
    ToggleHifzMode event,
    Emitter<HifzState> emit,
  ) {
    final nextActive = event.enabled ?? !state.isHifzModeActive;
    emit(state.copyWith(
      isHifzModeActive: nextActive,
      revealedVerseKeys: const {},
      revealedWordKeys: const {},
    ));
  }

  void _onSetHifzMaskingType(
    SetHifzMaskingType event,
    Emitter<HifzState> emit,
  ) {
    emit(state.copyWith(
      maskingType: event.maskingType,
      revealedVerseKeys: const {},
      revealedWordKeys: const {},
    ));
  }

  void _onToggleVerseReveal(
    ToggleVerseReveal event,
    Emitter<HifzState> emit,
  ) {
    final updated = Set<String>.from(state.revealedVerseKeys);
    if (updated.contains(event.verseKey)) {
      updated.remove(event.verseKey);
    } else {
      updated.add(event.verseKey);
    }
    emit(state.copyWith(revealedVerseKeys: updated));
  }

  void _onToggleWordReveal(
    ToggleWordReveal event,
    Emitter<HifzState> emit,
  ) {
    final updated = Set<String>.from(state.revealedWordKeys);
    if (updated.contains(event.wordKey)) {
      updated.remove(event.wordKey);
    } else {
      updated.add(event.wordKey);
    }
    emit(state.copyWith(revealedWordKeys: updated));
  }

  void _onClearRevealedItems(
    ClearRevealedItems event,
    Emitter<HifzState> emit,
  ) {
    emit(state.copyWith(
      revealedVerseKeys: const {},
      revealedWordKeys: const {},
    ));
  }
}

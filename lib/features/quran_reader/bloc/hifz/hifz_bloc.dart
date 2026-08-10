import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/hifz_database_helper.dart';
import '../../data/models/hifz_plan_model.dart';
import 'hifz_event.dart';
import 'hifz_state.dart';

class HifzBloc extends Bloc<HifzEvent, HifzState> {
  final HifzDatabaseHelper _dbHelper = HifzDatabaseHelper();

  HifzBloc() : super(const HifzState()) {
    on<LoadHifzData>(_onLoadHifzData);
    on<ToggleHifzMode>(_onToggleHifzMode);
    on<SetHifzMaskingType>(_onSetHifzMaskingType);
    on<ToggleVerseReveal>(_onToggleVerseReveal);
    on<ToggleWordReveal>(_onToggleWordReveal);
    on<ClearRevealedItems>(_onClearRevealedItems);
    on<UpdateVerseHifzStatus>(_onUpdateVerseHifzStatus);
    on<CreateHifzPlanEvent>(_onCreateHifzPlan);
    on<DeleteHifzPlanEvent>(_onDeleteHifzPlan);
  }

  Future<void> _onLoadHifzData(
    LoadHifzData event,
    Emitter<HifzState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final plans = await _dbHelper.getPlans();
      final itemsList = await _dbHelper.getHifzItems();
      final itemsMap = {for (final item in itemsList) item.verseKey: item};
      emit(state.copyWith(
        plans: plans,
        hifzItems: itemsMap,
        isLoading: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
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

  Future<void> _onUpdateVerseHifzStatus(
    UpdateVerseHifzStatus event,
    Emitter<HifzState> emit,
  ) async {
    final item = HifzItemModel(
      verseKey: event.verseKey,
      surahNumber: event.surahNumber,
      ayahNumber: event.ayahNumber,
      pageNumber: event.pageNumber,
      status: event.status,
      lastReviewedAt: DateTime.now().toIso8601String(),
    );
    await _dbHelper.upsertHifzItem(item);

    final updatedMap = Map<String, HifzItemModel>.from(state.hifzItems);
    updatedMap[event.verseKey] = item;
    emit(state.copyWith(hifzItems: updatedMap));
  }

  Future<void> _onCreateHifzPlan(
    CreateHifzPlanEvent event,
    Emitter<HifzState> emit,
  ) async {
    final plan = HifzPlanModel(
      id: 0,
      title: event.title,
      surahNumber: event.surahNumber,
      startPage: event.startPage,
      endPage: event.endPage,
      targetVersesCount: event.targetVersesCount,
      createdAt: DateTime.now().toIso8601String(),
    );
    await _dbHelper.insertPlan(plan);
    final plans = await _dbHelper.getPlans();
    emit(state.copyWith(plans: plans));
  }

  Future<void> _onDeleteHifzPlan(
    DeleteHifzPlanEvent event,
    Emitter<HifzState> emit,
  ) async {
    await _dbHelper.deletePlan(event.planId);
    final plans = await _dbHelper.getPlans();
    emit(state.copyWith(plans: plans));
  }
}

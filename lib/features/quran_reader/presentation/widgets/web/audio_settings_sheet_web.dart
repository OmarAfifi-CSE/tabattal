import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/reciter_localization.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_event.dart';
import '../audio_selector_button.dart';

// ─── Public API ─────────────────────────────────────────────────────────────

/// Shows the unified audio settings bottom sheet for web.
///
/// [verseId] – if provided, tapping "ابدأ الاستماع" will play that verse.
///              Pass null to only show reciter/repeat settings without triggering play.
void showAudioSettingsSheetWeb(BuildContext context, {int? verseId}) {
  final audioBloc = context.read<AudioBloc>();
  final audioPrefs = context.read<AudioPreferencesService>();
  final isEn = Localizations.localeOf(context).languageCode == 'en';

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.cardCream,
    constraints: const BoxConstraints(maxWidth: 450),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (_) => Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: MultiBlocProvider(
        providers: [BlocProvider.value(value: audioBloc)],
        child: _AudioSettingsSheetContent(
          verseId: verseId,
          audioPrefs: audioPrefs,
        ),
      ),
    ),
  );
}

// ─── Sheet Content ──────────────────────────────────────────────────────────

class _AudioSettingsSheetContent extends StatefulWidget {
  final int? verseId;
  final AudioPreferencesService audioPrefs;

  const _AudioSettingsSheetContent({
    required this.verseId,
    required this.audioPrefs,
  });

  @override
  State<_AudioSettingsSheetContent> createState() =>
      _AudioSettingsSheetContentState();
}

class _AudioSettingsSheetContentState
    extends State<_AudioSettingsSheetContent> {
  late String _selectedCategory;
  late String _selectedReciter;
  late int _selectedRepeatCount;
  late bool _playOnce;

  static const List<int> _repeatOptions = [0, 2, 3, -1];

  String _getRepeatLabel(BuildContext context, int count) {
    final l10n = AppLocalizations.of(context)!;
    switch (count) {
      case -1:
        return l10n.audioRepeatContinuous;
      case 0:
        return l10n.audioRepeatNone;
      case 2:
        return l10n.audioRepeatTwice;
      case 3:
        return l10n.audioRepeatThrice;
      default:
        return l10n.audioRepeatNone;
    }
  }

  @override
  void initState() {
    super.initState();
    final bloc = context.read<AudioBloc>();
    _selectedRepeatCount = bloc.currentRepeatCount;
    _playOnce = bloc.playOnce;
    if (!_repeatOptions.contains(_selectedRepeatCount)) {
      _selectedRepeatCount = 0;
    }

    _selectedCategory = bloc.currentCategory;
    _selectedReciter = bloc.currentReciter;
  }

  List<String> get _recitersForCategory =>
      AudioDownloadManager.reciterCategories[_selectedCategory]!.keys.toList();

  void _onCategoryChanged(String newCat) {
    setState(() {
      _selectedCategory = newCat;
      final reciters =
          AudioDownloadManager.reciterCategories[newCat]!.keys.toList();
      _selectedReciter = reciters.first;
    });
    widget.audioPrefs.saveCategory(newCat);
  }

  void _onReciterChanged(String newReciter) {
    setState(() => _selectedReciter = newReciter);
    widget.audioPrefs.saveReciter(newReciter);
  }

  void _onRepeatChanged(int repeatCount) {
    setState(() => _selectedRepeatCount = repeatCount);
    context.read<AudioBloc>().add(ChangeRepeatCount(repeatCount));
  }

  void _onPlayOnceChanged(bool value) {
    setState(() => _playOnce = value);
    context.read<AudioBloc>().add(ChangePlayOnce(value));
  }

  void _applyAndPlay() {
    context.read<AudioBloc>().add(
      ChangeReciter(_selectedCategory, _selectedReciter),
    );
    if (widget.verseId != null) {
      context.read<AudioBloc>().add(PlayVerse('', widget.verseId!));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final categories = AudioDownloadManager.reciterCategories.keys.toList();
    final reciters = _recitersForCategory;

    return Padding(
      padding: EdgeInsets.only(
        bottom: math.max(
          MediaQuery.viewInsetsOf(context).bottom,
          MediaQuery.paddingOf(context).bottom,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Title
            Center(
              child: Text(
                AppLocalizations.of(context)!.audioSettingsTitle,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Category Selector
            AudioSelectorButton<String>(
              icon: Icons.category_rounded,
              label: AppLocalizations.of(context)!.audioTypeLabel,
              value: _selectedCategory,
              items: categories,
              itemHeight: 42,
              onChanged: (val) => _onCategoryChanged(val),
              labelBuilder: (item) => ReciterLocalization.localizeByLang(isEn, item),
            ),
            const SizedBox(height: 10),

            // ── Reciter Selector
            AudioSelectorButton<String>(
              icon: Icons.mic_rounded,
              label: AppLocalizations.of(context)!.audioReciterLabel,
              value: _selectedReciter,
              items: reciters,
              itemHeight: 42,
              maxHeight: 210,
              onChanged: (val) => _onReciterChanged(val),
              labelBuilder: (item) => ReciterLocalization.localizeByLang(isEn, item),
            ),
            const SizedBox(height: 10),

            // ── Repeat Selector
            AudioSelectorButton<int>(
              icon: Icons.repeat_rounded,
              label: AppLocalizations.of(context)!.audioRepeatLabel,
              value: _selectedRepeatCount,
              items: _repeatOptions,
              itemHeight: 34,
              maxHeight: 136,
              onChanged: _onRepeatChanged,
              labelBuilder: (item) => _getRepeatLabel(context, item),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceCream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_outline_rounded,
                        color: AppColors.accentGold,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.menuListenOnce,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _playOnce,
                    activeTrackColor: AppColors.accentGold.withValues(alpha: 0.5),
                    activeThumbColor: AppColors.accentGold,
                    onChanged: _onPlayOnceChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Play / Apply button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: Icon(
                widget.verseId != null
                    ? Icons.play_arrow_rounded
                    : Icons.check_rounded,
                size: 22,
              ),
              label: Text(
                widget.verseId != null
                    ? AppLocalizations.of(context)!.audioStartListening
                    : AppLocalizations.of(context)!.audioSaveSettings,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _applyAndPlay,
            ),
          ],
        ),
      ),
    );
  }
}

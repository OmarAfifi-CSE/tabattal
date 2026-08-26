import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/reciter_localization.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_event.dart';
import '../audio_selector_button.dart';

// ─── Public API ─────────────────────────────────────────────────────────────

/// Shows the unified audio settings bottom sheet for tablet.
///
/// [verseId] – if provided, tapping "ابدأ الاستماع" will play that verse.
///              Pass null to only show reciter/repeat settings without triggering play.
void showAudioSettingsSheetTablet(BuildContext context, {int? verseId}) {
  final audioBloc = context.read<AudioBloc>();
  final audioPrefs = context.read<AudioPreferencesService>();
  final isEn = Localizations.localeOf(context).languageCode == 'en';
  final isLandscape =
      MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

  if (isLandscape) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.cardCream,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
          child: Directionality(
            textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
            child: MultiBlocProvider(
              providers: [BlocProvider.value(value: audioBloc)],
              child: _AudioSettingsSheetContent(
                verseId: verseId,
                audioPrefs: audioPrefs,
              ),
            ),
          ),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardCream,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
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
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: math.max(
          MediaQuery.viewInsetsOf(context).bottom,
          MediaQuery.paddingOf(context).bottom,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: isLandscape ? 420 : MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              isLandscape ? 16.0 : 20.w,
              isLandscape ? 12.0 : 8.h,
              isLandscape ? 16.0 : 20.w,
              isLandscape ? 14.0 : 16.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Drag handle or Dialog Header ──
                if (!isLandscape)
                  Center(
                    child: Container(
                      width: 48.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                // ── Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isLandscape) const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.audioSettingsTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isLandscape ? 17.0 : 24.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isLandscape)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: AppColors.inkBrown,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isLandscape ? 10.0 : 16.h),

                // ── Category Selector
                AudioSelectorButton<String>(
                  icon: Icons.category_rounded,
                  label: AppLocalizations.of(context)!.audioTypeLabel,
                  value: _selectedCategory,
                  items: categories,
                  height: isLandscape ? 44.0 : 56.h,
                  itemHeight: isLandscape ? 36.0 : 44.h,
                  maxHeight: 176.h,
                  labelFontSize: isLandscape ? 11.5 : 14.sp,
                  valueFontSize: isLandscape ? 14.0 : 18.5.sp,
                  itemFontSize: isLandscape ? 14.0 : 18.sp,
                  iconSize: isLandscape ? 18.0 : 24.sp,
                  onChanged: (val) => _onCategoryChanged(val),
                  labelBuilder: (item) =>
                      ReciterLocalization.localizeByLang(isEn, item),
                ),
                SizedBox(height: isLandscape ? 8.0 : 12.h),

                // ── Reciter Selector
                AudioSelectorButton<String>(
                  icon: Icons.mic_rounded,
                  label: AppLocalizations.of(context)!.audioReciterLabel,
                  value: _selectedReciter,
                  items: reciters,
                  height: isLandscape ? 44.0 : 56.h,
                  itemHeight: isLandscape ? 36.0 : 44.h,
                  maxHeight: 176.h,
                  labelFontSize: isLandscape ? 11.5 : 14.sp,
                  valueFontSize: isLandscape ? 14.0 : 18.5.sp,
                  itemFontSize: isLandscape ? 14.0 : 18.sp,
                  iconSize: isLandscape ? 18.0 : 24.sp,
                  onChanged: (val) => _onReciterChanged(val),
                  labelBuilder: (item) =>
                      ReciterLocalization.localizeByLang(isEn, item),
                ),
                SizedBox(height: isLandscape ? 8.0 : 12.h),

                // ── Repeat Selector
                AudioSelectorButton<int>(
                  icon: Icons.repeat_rounded,
                  label: AppLocalizations.of(context)!.audioRepeatLabel,
                  value: _selectedRepeatCount,
                  items: _repeatOptions,
                  height: isLandscape ? 44.0 : 56.h,
                  itemHeight: isLandscape ? 28.0 : 30.h,
                  maxHeight: 110.h,
                  labelFontSize: isLandscape ? 11.5 : 14.sp,
                  valueFontSize: isLandscape ? 14.0 : 18.5.sp,
                  itemFontSize: isLandscape ? 13.0 : 15.sp,
                  iconSize: isLandscape ? 18.0 : 24.sp,
                  onChanged: _onRepeatChanged,
                  labelBuilder: (item) => _getRepeatLabel(context, item),
                ),
                SizedBox(height: isLandscape ? 8.0 : 14.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 12.0 : 16.w,
                    vertical: isLandscape ? 3.0 : 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.r),
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
                            size: isLandscape ? 20.0 : 26.sp,
                          ),
                          SizedBox(width: isLandscape ? 8.0 : 10.w),
                          Text(
                            AppLocalizations.of(context)!.menuListenOnce,
                            style: TextStyle(
                              fontSize: isLandscape ? 13.5 : 18.5.sp,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _playOnce,
                        activeTrackColor:
                            AppColors.accentGold.withValues(alpha: 0.5),
                        activeThumbColor: AppColors.accentGold,
                        onChanged: _onPlayOnceChanged,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isLandscape ? 12.0 : 20.h),

                // ── Play / Apply button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isLandscape ? 10.0 : 14.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(
                    widget.verseId != null
                        ? Icons.play_arrow_rounded
                        : Icons.check_rounded,
                    size: isLandscape ? 20.0 : 26.sp,
                  ),
                  label: Text(
                    widget.verseId != null
                        ? AppLocalizations.of(context)!.audioStartListening
                        : AppLocalizations.of(context)!.audioSaveSettings,
                    style: TextStyle(
                      fontSize: isLandscape ? 14.5 : 19.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _applyAndPlay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/utils/web_safe_size.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../core/utils/reciter_localization.dart';
import '../../../../../core/services/audio_preferences_service.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_event.dart';

// ─── Public API ─────────────────────────────────────────────────────────────

/// Shows the unified audio settings bottom sheet.
///
/// [verseId] – if provided, tapping "ابدأ الاستماع" will play that verse.
///              Pass null to only show reciter/repeat settings without triggering play.
void showAudioSettingsSheetMobile(BuildContext context, {int? verseId}) {
  final audioBloc = context.read<AudioBloc>();
  final audioPrefs = context.read<AudioPreferencesService>();
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.cardCream,
    constraints: MediaQuery.sizeOf(context).width > 600
        ? const BoxConstraints(maxWidth: 450)
        : null,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.wR)),
    ),
    isScrollControlled: true,
    builder: (_) => MultiBlocProvider(
      providers: [BlocProvider.value(value: audioBloc)],
      child: _AudioSettingsSheetContent(
        verseId: verseId,
        audioPrefs: audioPrefs,
      ),
    ),
  );
}

// ─── Internal Widget ────────────────────────────────────────────────────────

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
      _selectedRepeatCount =
          0; // Fallback to default if saved value was removed
    }

    _selectedCategory = bloc.currentCategory;
    _selectedReciter = bloc.currentReciter;
  }

  List<String> get _recitersForCategory =>
      AudioDownloadManager.reciterCategories[_selectedCategory]!.keys.toList();

  void _onCategoryChanged(String newCat) {
    setState(() {
      _selectedCategory = newCat;
      final reciters = AudioDownloadManager.reciterCategories[newCat]!.keys
          .toList();
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
    context.read<AudioBloc>().add(ChangeReciter(_selectedCategory, _selectedReciter));
    if (widget.verseId != null) {
      context.read<AudioBloc>().add(PlayVerse('', widget.verseId!));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = AudioDownloadManager.reciterCategories.keys.toList();
    final reciters = _recitersForCategory;

    return Padding(
      padding: EdgeInsets.only(
        bottom: math.max(MediaQuery.of(context).viewInsets.bottom, MediaQuery.paddingOf(context).bottom),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(20.wW, 10.wH, 20.wW, 28.wH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle
            Center(
              child: Container(
                width: 48.wW,
                height: 4.wH,
                margin: EdgeInsets.only(bottom: 14.wH),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(2.wR),
                ),
              ),
            ),
            // ── Title
            Center(
              child: Text(
                AppLocalizations.of(context)!.audioSettingsTitle,
                style: TextStyle(
                  fontSize: 20.wSp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: 18.wH),

            // ── Category Selector
            _SelectorButton<String>(
              icon: Icons.category_rounded,
              label: AppLocalizations.of(context)!.audioTypeLabel,
              value: _selectedCategory,
              items: categories,
              onChanged: (val) => _onCategoryChanged(val),
              labelBuilder: (context, item) => ReciterLocalization.localize(context, item),
            ),
            SizedBox(height: 12.wH),

            // ── Reciter Selector
            _SelectorButton<String>(
              icon: Icons.mic_rounded,
              label: AppLocalizations.of(context)!.audioReciterLabel,
              value: _selectedReciter,
              items: reciters,
              onChanged: (val) => _onReciterChanged(val),
              labelBuilder: (context, item) => ReciterLocalization.localize(context, item),
            ),
            SizedBox(height: 20.wH),

            // ── Repeat Selector
            _SelectorButton<int>(
              icon: Icons.repeat_rounded,
              label: AppLocalizations.of(context)!.audioRepeatLabel,
              value: _selectedRepeatCount,
              items: _repeatOptions,
              onChanged: _onRepeatChanged,
              labelBuilder: (context, item) => _getRepeatLabel(context, item),
            ),
            SizedBox(height: 16.wH),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.wW, vertical: 2.wH),
              decoration: BoxDecoration(
                color: AppColors.surfaceCream,
                borderRadius: BorderRadius.circular(10.wR),
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
                      Icon(Icons.looks_one_rounded, color: AppColors.accentGold, size: 20.wSp),
                      SizedBox(width: 8.wW),
                      Text(
                        AppLocalizations.of(context)!.menuListenOnce,
                        style: TextStyle(
                          fontSize: 14.wSp,
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
            SizedBox(height: 24.wH),

            // ── Play / Apply button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.wH),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.wR),
                ),
                elevation: 0.r,
              ),
              icon: Icon(
                widget.verseId != null
                    ? Icons.play_arrow_rounded
                    : Icons.check_rounded,
                size: 24.wSp,
              ),
              label: Text(
                widget.verseId != null
                    ? AppLocalizations.of(context)!.audioStartListening
                    : AppLocalizations.of(context)!.audioSaveSettings,
                style: TextStyle(fontSize: 17.wSp, fontWeight: FontWeight.bold),
              ),
              onPressed: _applyAndPlay,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────



/// A full-width dropdown button that displays a popup menu below it.
class _SelectorButton<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(BuildContext, T) labelBuilder;

  const _SelectorButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        return PopupMenuButton<T>(
          splashRadius: 0.1,
          position: PopupMenuPosition.under,
          color: AppColors.cardCream,
          elevation: 4.r,
          constraints: BoxConstraints(
            minWidth: layoutConstraints.maxWidth,
            maxWidth: layoutConstraints.maxWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.15)),
          ),
          clipBehavior: Clip.hardEdge,
          onSelected: onChanged,
          itemBuilder: (context) => [
            PopupMenuItem<T>(
              enabled: false,
              padding: EdgeInsets.zero,
              child: _PopupMenuScrollableContent<T>(
                items: items,
                value: value,
                labelBuilder: labelBuilder,
                maxHeight: 250.h,
                itemHeight: 40.h,
              ),
            ),
          ],
          child: Container(
            height: 52.wH,
            width: MediaQuery.sizeOf(context).width,
            padding: EdgeInsets.symmetric(horizontal: 12.wW),
            decoration: BoxDecoration(
              color: AppColors.surfaceCream,
              borderRadius: BorderRadius.circular(10.wR),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accentGold, size: 18.wSp),
                SizedBox(width: 8.wW),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.wSp,
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w600,
                        ),
                        textDirection:
                            Localizations.localeOf(context).languageCode == 'en'
                            ? TextDirection.ltr
                            : TextDirection.rtl,
                      ),
                      Text(
                        labelBuilder(context, value),
                        textAlign:
                            Localizations.localeOf(context).languageCode == 'en'
                            ? TextAlign.left
                            : TextAlign.right,
                        textDirection:
                            Localizations.localeOf(context).languageCode == 'en'
                            ? TextDirection.ltr
                            : TextDirection.rtl,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.wSp,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.accentGold,
                  size: 20.wSp,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PopupMenuScrollableContent<T> extends StatefulWidget {
  final List<T> items;
  final T value;
  final String Function(BuildContext, T) labelBuilder;
  final double maxHeight;
  final double itemHeight;

  const _PopupMenuScrollableContent({
    required this.items,
    required this.value,
    required this.labelBuilder,
    required this.maxHeight,
    required this.itemHeight,
  });

  @override
  State<_PopupMenuScrollableContent<T>> createState() => _PopupMenuScrollableContentState<T>();
}

class _PopupMenuScrollableContentState<T> extends State<_PopupMenuScrollableContent<T>> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final index = widget.items.indexOf(widget.value);
    double offset = 0;
    if (index != -1) {
      offset = (index * widget.itemHeight) - (widget.maxHeight / 2) + (widget.itemHeight / 2);
      if (offset < 0) offset = 0;
      double maxScroll = (widget.items.length * widget.itemHeight) - widget.maxHeight;
      if (maxScroll < 0) maxScroll = 0;
      if (offset > maxScroll) offset = maxScroll;
    }
    _scrollController = ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: RawScrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 4.w,
        radius: Radius.circular(8.wR),
        thumbColor: AppColors.accentGold.withValues(alpha: 0.5),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.items.map((item) {
              final isSelected = item == widget.value;
              return InkWell(
                onTap: () => Navigator.pop(context, item),
                child: Container(
                  width: double.infinity,
                  height: widget.itemHeight,
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  alignment: Alignment.centerRight,
                  color: isSelected
                      ? AppColors.accentGold.withValues(alpha: 0.1)
                      : Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: Icon(
                            Icons.check_rounded,
                            color: AppColors.accentGold,
                            size: 16.r,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          widget.labelBuilder(context, item),
                          textAlign:
                              Localizations.localeOf(context).languageCode == 'en'
                              ? TextAlign.left
                              : TextAlign.right,
                          textDirection:
                              Localizations.localeOf(context).languageCode == 'en'
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}



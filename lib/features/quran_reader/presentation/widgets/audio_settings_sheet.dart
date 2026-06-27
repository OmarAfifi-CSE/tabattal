import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/audio_download_manager.dart';
import '../../../../core/services/audio_preferences_service.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_event.dart';

// ─── Public API ─────────────────────────────────────────────────────────────

/// Shows the unified audio settings bottom sheet.
///
/// [verseId] – if provided, tapping "ابدأ الاستماع" will play that verse.
///              Pass null to only show reciter/repeat settings without triggering play.
void showAudioSettingsSheet(BuildContext context, {int? verseId}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.cardCream,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
    isScrollControlled: true,
    builder: (_) => MultiBlocProvider(
      providers: [BlocProvider.value(value: context.read<AudioBloc>())],
      child: _AudioSettingsSheetContent(
        verseId: verseId,
        audioPrefs: context.read<AudioPreferencesService>(),
      ),
    ),
  );
}

// ─── Internal Widget ────────────────────────────────────────────────────────

class _AudioSettingsSheetContent extends StatefulWidget {
  final int? verseId;
  final AudioPreferencesService audioPrefs;

  const _AudioSettingsSheetContent({required this.verseId, required this.audioPrefs});

  @override
  State<_AudioSettingsSheetContent> createState() => _AudioSettingsSheetContentState();
}

class _AudioSettingsSheetContentState extends State<_AudioSettingsSheetContent> {
  late String _selectedCategory;
  late String _selectedReciter;
  late int _selectedRepeatCount;

  static const List<int> _repeatOptions = [0, 2, 3, -1];
  String _getRepeatLabel(int count) {
    switch (count) {
      case -1:
        return 'تكرار مستمر للآية';
      case 0:
        return 'بدون تكرار (استمرار)';
      case 2:
        return 'تكرار مرتين';
      case 3:
        return 'تكرار 3 مرات';
      default:
        return 'بدون تكرار (استمرار)';
    }
  }

  @override
  void initState() {
    super.initState();
    final bloc = context.read<AudioBloc>();
    _selectedRepeatCount = bloc.currentRepeatCount;
    if (!_repeatOptions.contains(_selectedRepeatCount)) {
      _selectedRepeatCount = 0; // Fallback to default if saved value was removed
    }

    // Find category for current reciter
    final currentReciter = bloc.currentReciter;
    String foundCategory = widget.audioPrefs.category;
    String foundReciter = currentReciter;

    for (final entry in AudioDownloadManager.reciterCategories.entries) {
      if (entry.value.containsKey(currentReciter)) {
        foundCategory = entry.key;
        foundReciter = currentReciter;
        break;
      }
    }
    _selectedCategory = foundCategory;
    _selectedReciter = foundReciter;
  }

  List<String> get _recitersForCategory =>
      AudioDownloadManager.reciterCategories[_selectedCategory]!.keys.toList();

  void _onCategoryChanged(String newCat) {
    setState(() {
      _selectedCategory = newCat;
      final reciters = AudioDownloadManager.reciterCategories[newCat]!.keys.toList();
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

  void _applyAndPlay() {
    context.read<AudioBloc>().add(ChangeReciter(_selectedReciter));
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle
            Center(
              child: Container(
                width: 48.w, height: 4.h,
                margin: EdgeInsets.only(bottom: 14.h),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            // ── Title
            Center(
              child: Text(
                'إعدادات الاستماع',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
            SizedBox(height: 18.h),

            // ── Category Selector
            _SelectorButton(
              icon: Icons.category_rounded,
              label: 'النوع',
              value: _selectedCategory,
              items: categories,
              onChanged: _onCategoryChanged,
            ),
            SizedBox(height: 12.h),

            // ── Reciter Selector
            _SelectorButton(
              icon: Icons.mic_rounded,
              label: 'القارئ',
              value: _selectedReciter,
              items: reciters,
              onChanged: _onReciterChanged,
            ),
            SizedBox(height: 20.h),

            // ── Repeat Selector
            const _SectionLabel(icon: Icons.repeat_rounded, label: 'تكرار الآية'),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: false,
                    value: _selectedRepeatCount,
                    icon: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentGold),
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    onChanged: (val) {
                      if (val != null) _onRepeatChanged(val);
                    },
                  items: _repeatOptions.map((count) {
                    return DropdownMenuItem<int>(
                      value: count,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Text(
                          _getRepeatLabel(count),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            ),
            SizedBox(height: 24.h),

            // ── Play / Apply button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
              icon: Icon(widget.verseId != null ? Icons.play_arrow_rounded : Icons.check_rounded, size: 24.sp),
              label: Text(
                widget.verseId != null ? 'ابدأ الاستماع' : 'حفظ الإعدادات',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
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

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, color: AppColors.accentGold, size: 18.sp),
        SizedBox(width: 6.w),
        Text(
          label,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }
}

/// A full-width dropdown button that displays a popup menu below it.
class _SelectorButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _SelectorButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      position: PopupMenuPosition.under,
      color: Colors.white,
      elevation: 4,
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 350),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.15)),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => items.map((item) {
        final isSelected = item == value;
        return PopupMenuItem<String>(
          value: item,
          height: 40,
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerRight,
            color: isSelected ? AppColors.accentGold.withValues(alpha: 0.1) : Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_rounded, color: AppColors.accentGold, size: 16),
                  ),
                Expanded(
                  child: Text(
                    item,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 52.h,
        width: MediaQuery.sizeOf(context).width,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentGold, size: 18.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10.sp, color: AppColors.accentGold, fontWeight: FontWeight.w600),
                    textDirection: TextDirection.rtl,
                  ),
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentGold, size: 20.sp),
          ],
        ),
      ),
    );
  }
}

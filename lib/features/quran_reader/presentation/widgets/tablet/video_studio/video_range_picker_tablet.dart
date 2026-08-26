import 'package:flutter/material.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../verse_card/helpers/verse_card_text_utils.dart';

class VideoRangePickerTablet extends StatelessWidget {
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  final ValueChanged<int> onStartAyahChanged;
  final ValueChanged<int> onEndAyahChanged;

  const VideoRangePickerTablet({
    super.key,
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.onStartAyahChanged,
    required this.onEndAyahChanged,
  });

  int get totalAyahsInSurah => QuranMetadata.getVerseCountForSurah(surahNumber);

  int _getMaxEndAyah(int start) {
    return (start + 9).clamp(1, totalAyahsInSurah);
  }

  void _showAyahPickerDialog({
    required BuildContext context,
    required String title,
    required int currentValue,
    required List<int> options,
    required ValueChanged<int> onSelected,
  }) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.cardCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
            child: Directionality(
              textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8.0),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 1.4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final ayah = options[index];
                          final isSelected = ayah == currentValue;

                          return InkWell(
                            onTap: () {
                              onSelected(ayah);
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(10.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accentGold
                                    : AppColors.accentGold
                                        .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.accentGold
                                      : AppColors.accentGold
                                          .withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                VerseCardTextUtils.toArabicDigits(ayah),
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final startOptions = List.generate(totalAyahsInSurah, (i) => i + 1);
    final maxEnd = _getMaxEndAyah(startAyah);
    final endOptions = List.generate(
      maxEnd - startAyah + 1,
      (i) => startAyah + i,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.videoStudioVerseRange,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4.0),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5.0),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.28),
                  width: 1,
                ),
              ),
              child: Text(
                Localizations.localeOf(context).languageCode == 'en'
                    ? 'Surah ${QuranMetadata.getSurahNameEnglish(surahNumber)}'
                    : 'سورة ${QuranMetadata.getSurahName(surahNumber)}',
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  _showAyahPickerDialog(
                    context: context,
                    title: l10n.verseCardStartAyah,
                    currentValue: startAyah,
                    options: startOptions,
                    onSelected: (val) {
                      onStartAyahChanged(val);
                    },
                  );
                },
                borderRadius: BorderRadius.circular(10.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 5.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'en'
                              ? 'From Ayah $startAyah'
                              : 'من آية ${VerseCardTextUtils.toArabicDigits(startAyah)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16.0,
                        color: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6.0),
            Expanded(
              child: InkWell(
                onTap: () {
                  _showAyahPickerDialog(
                    context: context,
                    title: l10n.verseCardEndAyah,
                    currentValue: endAyah,
                    options: endOptions,
                    onSelected: (val) {
                      onEndAyahChanged(val);
                    },
                  );
                },
                borderRadius: BorderRadius.circular(10.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 5.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'en'
                              ? 'To Ayah $endAyah'
                              : 'إلى آية ${VerseCardTextUtils.toArabicDigits(endAyah)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16.0,
                        color: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

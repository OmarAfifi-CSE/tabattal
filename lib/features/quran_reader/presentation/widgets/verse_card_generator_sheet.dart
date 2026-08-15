import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_text_utils.dart';
import '../../../../core/widgets/mixed_direction_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/bloc/settings_bloc.dart';
import '../../data/models/verse_model.dart';

/// Global registry for the current Quran page repaint boundary key.
/// Set by QuranMobileScreen when the active page changes, used by
/// VerseCardGeneratorSheet to capture a live screenshot of the page.
class QuranPageRepaintRegistry {
  QuranPageRepaintRegistry._();
  static GlobalKey? currentPageKey;
}

/// Supported share formats in the generator modal.
enum ShareFormat { image, text, fullPage }

/// Shows the Verse Card Generator modal.
void showVerseCardGeneratorModal(
  BuildContext context, {
  required VerseModel verse,
  String? tafsirText,
  String? translationText,
  GlobalKey? pageRepaintKey,
}) {
  const isWeb = kIsWeb;
  final isWide = MediaQuery.sizeOf(context).width > 600;

  if (isWide || isWeb) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 800),
          child: VerseCardGeneratorSheet(
            verse: verse,
            tafsirText: tafsirText,
            translationText: translationText,
            pageRepaintKey: pageRepaintKey,
          ),
        ),
      ),
    );
  } else {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.85;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: VerseCardGeneratorSheet(
          verse: verse,
          tafsirText: tafsirText,
          translationText: translationText,
          pageRepaintKey: pageRepaintKey,
        ),
      ),
    );
  }
}

/// Represents a color theme for the Verse Card.
class VerseCardTheme {
  final String name;
  final String nameEn;
  final Color backgroundColor;
  final Color cardBackground;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color borderColor;

  const VerseCardTheme({
    required this.name,
    required this.nameEn,
    required this.backgroundColor,
    required this.cardBackground,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.borderColor,
  });

  String getLocalizedName(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'en' ? nameEn : name;
  }

  static const List<VerseCardTheme> themes = [
    VerseCardTheme(
      name: 'كريمي',
      nameEn: 'Cream',
      backgroundColor: Color(0xFFFBF7F0),
      cardBackground: Color(0xFFF7F2E7),
      primaryTextColor: Color(0xFF2C2520),
      secondaryTextColor: Color(0xFF5D4A3A),
      accentColor: Color(0xFFB59A53),
      borderColor: Color(0xFFEAD8BA),
    ),
    VerseCardTheme(
      name: 'أبيض',
      nameEn: 'White',
      backgroundColor: Color(0xFFFFFFFF),
      cardBackground: Color(0xFFF7F7F7),
      primaryTextColor: Color(0xFF1E1E1E),
      secondaryTextColor: Color(0xFF555555),
      accentColor: Color(0xFFC7A263),
      borderColor: Color(0xFFF0E5D1),
    ),
    VerseCardTheme(
      name: 'عتيق',
      nameEn: 'Vintage',
      backgroundColor: Color(0xFFF5EBE0),
      cardBackground: Color(0xFFEFE3D3),
      primaryTextColor: Color(0xFF3A2D21),
      secondaryTextColor: Color(0xFF6E5642),
      accentColor: Color(0xFF9C7A44),
      borderColor: Color(0xFFE3D4C1),
    ),
    VerseCardTheme(
      name: 'روز جولد',
      nameEn: 'Rose Gold',
      backgroundColor: Color(0xFFFDF8F5),
      cardBackground: Color(0xFFF7ECE7),
      primaryTextColor: Color(0xFF38282A),
      secondaryTextColor: Color(0xFF6B5154),
      accentColor: Color(0xFFD89A88),
      borderColor: Color(0xFFF0DCD5),
    ),
    VerseCardTheme(
      name: 'نعناعي',
      nameEn: 'Mint',
      backgroundColor: Color(0xFFF0F7F4),
      cardBackground: Color(0xFFE1EFEA),
      primaryTextColor: Color(0xFF1B3B2B),
      secondaryTextColor: Color(0xFF436B56),
      accentColor: Color(0xFF5B8A72),
      borderColor: Color(0xFFD6E8DB),
    ),
    VerseCardTheme(
      name: 'زيتوني',
      nameEn: 'Olive',
      backgroundColor: Color(0xFFF7F8F2),
      cardBackground: Color(0xFFECEFE5),
      primaryTextColor: Color(0xFF252B1E),
      secondaryTextColor: Color(0xFF535C48),
      accentColor: Color(0xFF9A9D49),
      borderColor: Color(0xFFDFE3D1),
    ),
    VerseCardTheme(
      name: 'ثلجي',
      nameEn: 'Ice',
      backgroundColor: Color(0xFFF4F8FA),
      cardBackground: Color(0xFFE5F0F5),
      primaryTextColor: Color(0xFF1D2830),
      secondaryTextColor: Color(0xFF425A70),
      accentColor: Color(0xFF7B99AD),
      borderColor: Color(0xFFD6E4EE),
    ),
    VerseCardTheme(
      name: 'رخامي',
      nameEn: 'Marble',
      backgroundColor: Color(0xFFF4F5F7),
      cardBackground: Color(0xFFE8ECF0),
      primaryTextColor: Color(0xFF1E252B),
      secondaryTextColor: Color(0xFF4C5866),
      accentColor: Color(0xFF7D8C9E),
      borderColor: Color(0xFFD8DFE8),
    ),
    VerseCardTheme(
      name: 'زمردي',
      nameEn: 'Emerald',
      backgroundColor: Color(0xFF0A1F18),
      cardBackground: Color(0xFF132D24),
      primaryTextColor: Color(0xFFFAF6F0),
      secondaryTextColor: Color(0xFFD0C3B0),
      accentColor: Color(0xFFD4AF37),
      borderColor: Color(0xFF1D3B30),
    ),
    VerseCardTheme(
      name: 'عنابي',
      nameEn: 'Burgundy',
      backgroundColor: Color(0xFF1A0C14),
      cardBackground: Color(0xFF27131F),
      primaryTextColor: Color(0xFFF8EEF2),
      secondaryTextColor: Color(0xFFC7A5B5),
      accentColor: Color(0xFFE0B36C),
      borderColor: Color(0xFF331B28),
    ),
    VerseCardTheme(
      name: 'ليلي',
      nameEn: 'Midnight',
      backgroundColor: Color(0xFF0D1117),
      cardBackground: Color(0xFF161B22),
      primaryTextColor: Color(0xFFF0F6FC),
      secondaryTextColor: Color(0xFF8B949E),
      accentColor: Color(0xFFE2C044),
      borderColor: Color(0xFF30363D),
    ),
  ];
}

class VerseCardGeneratorSheet extends StatefulWidget {
  final VerseModel verse;
  final String? tafsirText;
  final String? translationText;
  final GlobalKey? pageRepaintKey;

  const VerseCardGeneratorSheet({
    super.key,
    required this.verse,
    this.tafsirText,
    this.translationText,
    this.pageRepaintKey,
  });

  @override
  State<VerseCardGeneratorSheet> createState() => _VerseCardGeneratorSheetState();
}

class _VerseCardGeneratorSheetState extends State<VerseCardGeneratorSheet> {
  final GlobalKey _repaintKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  late int _startAyah;
  late int _endAyah;
  late int _totalAyahsInSurah;

  int _selectedThemeIndex = 0;
  bool _includeTafsir = false;
  bool _includeTranslation = false;
  ShareFormat _selectedFormat = ShareFormat.image;
  bool _isSharing = false;
  bool _isSaving = false;
  String _verseTextUthmani = '';
  bool _isLoadingText = true;
  String _tafsirText = '';
  String _translationText = '';
  bool _isLoadingTafsir = true;
  bool _isLoadingTranslation = true;

  // Full page snapshot (captured from live QuranPageWidgetMobile)
  Uint8List? _pageSnapshot;
  bool _isCapturingSnapshot = false;

  String? _statusMessage;
  bool _isSuccessStatus = true;

  VerseCardTheme get _activeTheme => VerseCardTheme.themes[_selectedThemeIndex];

  int get _surahNumber => int.tryParse(widget.verse.verseKey.split(':')[0]) ?? 1;

  @override
  void initState() {
    super.initState();
    _selectedThemeIndex = _getInitialThemeIndex();
    _startAyah = widget.verse.verseNumber;
    _endAyah = widget.verse.verseNumber;
    _totalAyahsInSurah = QuranMetadata.getVerseCountForSurah(_surahNumber);
    if (widget.tafsirText != null && widget.tafsirText!.trim().isNotEmpty) {
      _tafsirText = ArabicTextUtils.cleanTafsirOrHtml(widget.tafsirText!.trim());
      _includeTafsir = true;
    }
    if (widget.translationText != null && widget.translationText!.trim().isNotEmpty) {
      _translationText = ArabicTextUtils.cleanTafsirOrHtml(widget.translationText!.trim());
      _includeTranslation = true;
    }
    _loadAllVerseData();
    _loadFullPageData();
  }

  int _getInitialThemeIndex() {
    try {
      final settingsState = context.read<SettingsBloc>().state;
      final activeThemeId = settingsState.effectiveMushafTheme.id;
      final String targetName;
      switch (activeThemeId) {
        case 'white':
          targetName = 'أبيض';
          break;
        case 'parchment':
          targetName = 'عتيق';
          break;
        case 'roseGold':
          targetName = 'روز جولد';
          break;
        case 'mint':
          targetName = 'نعناعي';
          break;
        case 'olive':
          targetName = 'زيتوني';
          break;
        case 'iceBlue':
          targetName = 'ثلجي';
          break;
        case 'slate':
          targetName = 'رخامي';
          break;
        case 'emerald':
          targetName = 'زمردي';
          break;
        case 'burgundy':
          targetName = 'عنابي';
          break;
        case 'dark':
          targetName = 'ليلي';
          break;
        case 'cream':
        default:
          targetName = 'كريمي';
          break;
      }
      final idx = VerseCardTheme.themes.indexWhere((t) => t.name == targetName);
      return idx != -1 ? idx : 0;
    } catch (_) {
      return 0;
    }
  }

  int _getMaxEndAyah(int start) {
    // Allows selecting up to 25 verses in a range so full short surahs (e.g. Al-Ikhlas, Al-Falaq, Al-Nas, Al-Duha) can be shared in full!
    return (start + 24).clamp(1, _totalAyahsInSurah);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToStatusBanner() {
    // Wait for AnimatedSwitcher size expansion to complete layout before scrolling to absolute maxExtent
    Future.delayed(const Duration(milliseconds: 320), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showAyahPickerSheet({
    required BuildContext context,
    required String title,
    required int currentValue,
    required List<int> options,
    required ValueChanged<int> onSelected,
  }) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    const isWeb = kIsWeb;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardCream,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag indicator
                Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),

                // Header title + close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isWeb ? 17 : 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      splashRadius: 20,
                    ),
                  ],
                ),

                const Divider(height: 1),
                SizedBox(height: 12.h),

                // Grid of Ayah selection tiles
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWeb ? 5 : 4,
                      mainAxisSpacing: 10.h,
                      crossAxisSpacing: 10.w,
                      childAspectRatio: 2.1,
                    ),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final item = options[index];
                      final isSelected = item == currentValue;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelected(item);
                        },
                        borderRadius: BorderRadius.circular(12.r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentGold
                                : AppColors.surfaceCream,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentGold
                                  : AppColors.accentGold.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.accentGold.withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isEn ? 'Ayah $item' : 'آية $item',
                            style: TextStyle(
                              fontSize: isWeb ? 13 : 12.sp,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
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
        );
      },
    );
  }

  List<TextSpan> _qcfSpans = [];

  String _toArabicDigits(int number) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String str = number.toString();
    for (int i = 0; i < englishDigits.length; i++) {
      str = str.replaceAll(englishDigits[i], arabicDigits[i]);
    }
    return str;
  }

  String _cleanTextForSharing(String text) {
    return text
        .replaceAll('ٱ', 'ا')
        .replaceAll(RegExp(r'[\u06D6-\u06ED]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _loadAllVerseData() async {
    setState(() {
      _isLoadingText = true;
      _isLoadingTafsir = true;
      _isLoadingTranslation = true;
    });

    try {
      final db = await DatabaseHelper().database;
      await Future.wait([
        _loadVerseTextAndFont(db),
        _loadTafsirForRange(db),
        _loadTranslationForRange(db),
      ]);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingText = false;
          _isLoadingTafsir = false;
          _isLoadingTranslation = false;
        });
      }
    }
  }

  Future<void> _loadVerseTextAndFont(Database db) async {
    try {
      final verseKeys = List.generate(
        _endAyah - _startAyah + 1,
        (i) => '$_surahNumber:${_startAyah + i}',
      );

      final placeholders = List.filled(verseKeys.length, '?').join(',');
      final maps = await db.query(
        'quran_words',
        columns: ['code_v1', 'page', 'text_uthmani', 'char_type_name', 'verse_key'],
        where: 'verse_key IN ($placeholders)',
        whereArgs: verseKeys,
        orderBy: 'id ASC',
      );

      final searchMaps = await db.query(
        'quran_search',
        columns: ['text_uthmani', 'verse_key'],
        where: 'verse_key IN ($placeholders)',
        whereArgs: verseKeys,
        orderBy: 'id ASC',
      );

      final searchMap = {
        for (var m in searchMaps)
          m['verse_key'] as String: m['text_uthmani'] as String
      };

      if (maps.isNotEmpty) {
        final newSpans = <TextSpan>[];
        final verseUthmaniList = <String>[];

        for (int i = 0; i < verseKeys.length; i++) {
          final vk = verseKeys[i];
          final currentAyahNum = _startAyah + i;
          final wordsForVerse = maps.where((m) => m['verse_key'] == vk);
          if (wordsForVerse.isNotEmpty) {
            final pageNum = wordsForVerse.first['page'] as int;
            final pageStr = pageNum.toString().padLeft(3, '0');
            final fontFamily = 'QCF_P$pageStr';
            final codeV1Text = wordsForVerse.map((m) => m['code_v1'] as String).join(' ');

            if (newSpans.isNotEmpty) {
              newSpans.add(const TextSpan(text: ' '));
            }
            newSpans.add(
              TextSpan(
                text: codeV1Text,
                style: TextStyle(fontFamily: fontFamily),
              ),
            );

            final rawTextWords = searchMap[vk] ??
                wordsForVerse
                    .where((m) => m['char_type_name'] == 'word')
                    .map((m) => m['text_uthmani'] as String)
                    .join(' ');

            final cleanVerseText = _cleanTextForSharing(rawTextWords);
            final arabicAyahNum = _toArabicDigits(currentAyahNum);
            verseUthmaniList.add('$cleanVerseText ﴿$arabicAyahNum﴾');
          }
        }

        final combinedUthmani = verseUthmaniList.join(' ');

        if (mounted) {
          setState(() {
            _qcfSpans = newSpans;
            _verseTextUthmani = combinedUthmani;
            _isLoadingText = false;
          });
        }
        return;
      }

      // Fallback if quran_words table maps were empty
      final fallbackList = <String>[];
      for (int i = 0; i < searchMaps.length; i++) {
        final text = searchMaps[i]['text_uthmani'] as String;
        final currentAyahNum = _startAyah + i;
        final cleanText = _cleanTextForSharing(text);
        final arabicAyahNum = _toArabicDigits(currentAyahNum);
        fallbackList.add('$cleanText ﴿$arabicAyahNum﴾');
      }

      final fallbackText = fallbackList.isNotEmpty
          ? fallbackList.join(' ')
          : '${_cleanTextForSharing(widget.verse.textUthmani)} ﴿${_toArabicDigits(widget.verse.verseNumber)}﴾';

      if (mounted) {
        setState(() {
          _qcfSpans = [];
          _verseTextUthmani = fallbackText;
          _isLoadingText = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _qcfSpans = [];
          _verseTextUthmani = '${_cleanTextForSharing(widget.verse.textUthmani)} ﴿${_toArabicDigits(widget.verse.verseNumber)}﴾';
          _isLoadingText = false;
        });
      }
    }
  }

  Future<void> _loadTafsirForRange(Database db) async {
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'tafsir',
        where: 'verse_key LIKE ? AND resource_id = ?',
        whereArgs: ['$_surahNumber:%', 16],
        orderBy: 'CAST(substr(verse_key, instr(verse_key, ":") + 1) AS INTEGER) ASC',
      );

      if (maps.isEmpty) {
        if (mounted) {
          setState(() {
            _tafsirText = ArabicTextUtils.cleanTafsirOrHtml(widget.tafsirText ?? '');
            _isLoadingTafsir = false;
          });
        }
        return;
      }

      final Map<int, String> tafsirMap = {};
      for (final row in maps) {
        final vk = row['verse_key'] as String;
        final parts = vk.split(':');
        if (parts.length == 2) {
          final ayahNum = int.tryParse(parts[1]);
          final rawText = (row['text'] as String?)?.trim() ?? '';
          final cleanText = ArabicTextUtils.cleanTafsirOrHtml(rawText);
          if (ayahNum != null && cleanText.isNotEmpty) {
            tafsirMap[ayahNum] = cleanText;
          }
        }
      }

      final List<String> resultSegments = [];
      String lastGroupText = '';

      for (int ayah = _startAyah; ayah <= _endAyah; ayah++) {
        String verseTafsir = '';
        if (tafsirMap.containsKey(ayah)) {
          verseTafsir = tafsirMap[ayah]!;
        } else {
          for (int back = ayah - 1; back >= 1 && back >= ayah - 20; back--) {
            if (tafsirMap.containsKey(back)) {
              verseTafsir = tafsirMap[back]!;
              break;
            }
          }
        }

        if (verseTafsir.isNotEmpty && verseTafsir != lastGroupText) {
          resultSegments.add(verseTafsir);
          lastGroupText = verseTafsir;
        }
      }

      final combinedTafsir = resultSegments.isNotEmpty
          ? resultSegments.join('\n\n')
          : ArabicTextUtils.cleanTafsirOrHtml(widget.tafsirText ?? '');

      if (mounted) {
        setState(() {
          _tafsirText = combinedTafsir;
          _isLoadingTafsir = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tafsirText = ArabicTextUtils.cleanTafsirOrHtml(widget.tafsirText ?? '');
          _isLoadingTafsir = false;
        });
      }
    }
  }

  Future<void> _loadTranslationForRange(Database db) async {
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'translation',
        where: 'verse_key LIKE ? AND resource_id = ?',
        whereArgs: ['$_surahNumber:%', 20],
        orderBy: 'CAST(substr(verse_key, instr(verse_key, ":") + 1) AS INTEGER) ASC',
      );

      if (maps.isEmpty) {
        if (mounted) {
          setState(() {
            _translationText = ArabicTextUtils.cleanTafsirOrHtml(widget.translationText ?? '');
            _isLoadingTranslation = false;
          });
        }
        return;
      }

      final Map<int, String> translationMap = {};
      for (final row in maps) {
        final vk = row['verse_key'] as String;
        final parts = vk.split(':');
        if (parts.length == 2) {
          final ayahNum = int.tryParse(parts[1]);
          final rawText = (row['text'] as String?)?.trim() ?? '';
          final cleanText = ArabicTextUtils.cleanTafsirOrHtml(rawText);
          if (ayahNum != null && cleanText.isNotEmpty) {
            translationMap[ayahNum] = cleanText;
          }
        }
      }

      final List<String> resultSegments = [];
      for (int ayah = _startAyah; ayah <= _endAyah; ayah++) {
        final text = translationMap[ayah];
        if (text != null && text.isNotEmpty) {
          if (_startAyah == _endAyah) {
            resultSegments.add(text);
          } else {
            resultSegments.add('($ayah) $text');
          }
        }
      }

      final combinedTranslation = resultSegments.isNotEmpty
          ? resultSegments.join(' ')
          : ArabicTextUtils.cleanTafsirOrHtml(widget.translationText ?? '');

      if (mounted) {
        setState(() {
          _translationText = combinedTranslation;
          _isLoadingTranslation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _translationText = ArabicTextUtils.cleanTafsirOrHtml(widget.translationText ?? '');
          _isLoadingTranslation = false;
        });
      }
    }
  }

  Future<void> _loadFullPageData() async {
    if (_isCapturingSnapshot) return;
    setState(() => _isCapturingSnapshot = true);
    try {
      // Give the bottom sheet a frame to settle before capturing
      await Future.delayed(const Duration(milliseconds: 80));
      final key = widget.pageRepaintKey ?? QuranPageRepaintRegistry.currentPageKey;
      if (key == null) {
        setState(() => _isCapturingSnapshot = false);
        return;
      }
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isCapturingSnapshot = false);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (mounted) {
        setState(() {
          _pageSnapshot = byteData?.buffer.asUint8List();
          _isCapturingSnapshot = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCapturingSnapshot = false);
    }
  }

  Future<Uint8List?> _captureCardPng() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final double width = boundary.size.width;
      final double height = boundary.size.height;

      // 1. Render boundary to raw Skia image at Ultra-HD 4.0x resolution scale
      const double scale = 4.0;
      final ui.Image rawImage = await boundary.toImage(pixelRatio: scale);

      // 2. Draw rawImage onto an integer-sized solid background canvas at Ultra-HD resolution
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final double targetWidth = (width * scale).floorToDouble();
      final double targetHeight = (height * scale).floorToDouble();

      // Fill canvas with solid background color first (no transparent pixels anywhere!)
      final paint = Paint()
        ..color = _activeTheme.backgroundColor
        ..isAntiAlias = true;
      canvas.drawRect(Rect.fromLTWH(0, 0, targetWidth, targetHeight), paint);

      // Draw captured image onto the canvas with high quality anti-aliased filtering
      final imagePaint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      canvas.drawImageRect(
        rawImage,
        Rect.fromLTWH(0, 0, rawImage.width.toDouble(), rawImage.height.toDouble()),
        Rect.fromLTWH(0, 0, targetWidth, targetHeight),
        imagePaint,
      );

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(targetWidth.toInt(), targetHeight.toInt());
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// Opens native share sheet to share ONLY the generated PNG image.
  Future<void> _shareCard() async {
    if (_isSharing || _isSaving) return;
    setState(() {
      _isSharing = true;
      _statusMessage = null;
    });

    try {
      final imageBytes = await _captureCardPng();
      if (imageBytes == null || !mounted) {
        if (mounted) setState(() => _isSharing = false);
        return;
      }

      final isEn = mounted && Localizations.localeOf(context).languageCode == 'en';
      final surahName = isEn
          ? QuranMetadata.getSurahNameEnglish(_surahNumber)
          : QuranMetadata.getSurahName(_surahNumber);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = _startAyah == _endAyah
          ? 'Verse_${_surahNumber}_${_startAyah}_$timestamp.png'
          : 'Verse_${_surahNumber}_${_startAyah}_to_${_endAyah}_$timestamp.png';

      if (kIsWeb) {
        await Share.shareXFiles([
          XFile.fromData(
            imageBytes,
            mimeType: 'image/png',
            name: fileName,
          ),
        ]);
      } else {
        final tempDir = await getTemporaryDirectory();

        // Auto-cleanup previous temporary verse card share files to keep device storage clean
        try {
          final oldFiles = tempDir.listSync().whereType<File>().where(
                (file) => file.path.contains('Verse_') && file.path.endsWith('.png'),
              );
          for (final oldFile in oldFiles) {
            try {
              oldFile.deleteSync();
            } catch (_) {}
          }
        } catch (_) {}

        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(imageBytes);

        try {
          await Share.shareXFiles([
            XFile(tempFile.path, mimeType: 'image/png'),
          ]);
        } on MissingPluginException {
          // Fallback if app hasn't been recompiled after adding native package
          await Share.share(
            isEn
                ? '( $_verseTextUthmani ) — Surah $surahName'
                : '﴿ $_verseTextUthmani ﴾ — سورة $surahName',
          );
        }
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _statusMessage = 'يتطلب تفعيل المشاركة المباشرة إعادة تشغيل التطبيق.';
          _isSuccessStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'خطأ أثناء المشاركة: $e';
          _isSuccessStatus = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// Saves image directly to public Pictures/Tabattal gallery via ImageGallerySaver.
  Future<void> _saveCardImage() async {
    if (_isSaving || _isSharing) return;
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final imageBytes = await _captureCardPng();
      if (imageBytes == null || !mounted) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      final fileName = _startAyah == _endAyah
          ? 'Verse_${_surahNumber}_$_startAyah'
          : 'Verse_${_surahNumber}_${_startAyah}_to_$_endAyah';

      if (!kIsWeb) {
        if (Platform.isAndroid) {
          try {
            final picturesDir = Directory('/storage/emulated/0/Pictures/Tabattal');
            if (!picturesDir.existsSync()) {
              picturesDir.createSync(recursive: true);
            }
            final picFile = File('${picturesDir.path}/$fileName.png');
            await picFile.writeAsBytes(imageBytes);

            // Force Android OS MediaScanner to index image immediately in Gallery
            const channel = MethodChannel('com.omarafifi.tabattal/media_scanner');
            await channel.invokeMethod('scanFile', {'path': picFile.path});
          } catch (_) {}
        } else {
          final docsDir = await getApplicationDocumentsDirectory();
          final file = File('${docsDir.path}/$fileName.png');
          await file.writeAsBytes(imageBytes);
        }

        if (mounted) {
          setState(() {
            _statusMessage = 'تم حفظ الصورة في المعرض بنجاح';
            _isSuccessStatus = true;
          });
          _scrollToStatusBanner();
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = 'تم توليد بطاقة الصورة بنجاح';
            _isSuccessStatus = true;
          });
          _scrollToStatusBanner();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'خطأ أثناء حفظ الصورة: $e';
          _isSuccessStatus = false;
        });
        _scrollToStatusBanner();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getFormattedShareText(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahName = isEn
        ? QuranMetadata.getSurahNameEnglish(_surahNumber)
        : QuranMetadata.getSurahName(_surahNumber);
    final l10n = AppLocalizations.of(context)!;

    final rangeText = _startAyah == _endAyah
        ? (isEn ? 'Surah $surahName • Ayah $_startAyah' : 'سورة $surahName • آية $_startAyah')
        : (isEn ? 'Surah $surahName • Ayahs $_startAyah - $_endAyah' : 'سورة $surahName • الآيات ($_startAyah - $_endAyah)');

    final buffer = StringBuffer();
    buffer.writeln('( $_verseTextUthmani )');
    buffer.writeln();

    if (_includeTafsir && _tafsirText.trim().isNotEmpty) {
      buffer.writeln('【 ${l10n.verseCardTafsirBadge} 】');
      buffer.writeln(_tafsirText.trim());
      buffer.writeln();
    }

    if (_includeTranslation && _translationText.trim().isNotEmpty) {
      buffer.writeln('【 ${l10n.verseCardTranslationBadge} 】');
      buffer.writeln(_translationText.trim());
      buffer.writeln();
    }

    buffer.writeln(rangeText);
    return buffer.toString();
  }

  Future<void> _copyTextToClipboard(BuildContext context) async {
    final text = _getFormattedShareText(context);
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();

    if (mounted) {
      setState(() {
        _statusMessage = AppLocalizations.of(context)!.verseCardCopiedSuccess;
        _isSuccessStatus = true;
      });
      _scrollToStatusBanner();
    }
  }

  Widget _buildTextPreviewWidget(BuildContext context) {
    final theme = _activeTheme;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahName = isEn
        ? QuranMetadata.getSurahNameEnglish(_surahNumber)
        : QuranMetadata.getSurahName(_surahNumber);
    final l10n = AppLocalizations.of(context)!;

    final rangeText = _startAyah == _endAyah
        ? (isEn ? 'Surah $surahName • Ayah $_startAyah' : 'سورة $surahName • آية $_startAyah')
        : (isEn ? 'Surah $surahName • Ayahs $_startAyah - $_endAyah' : 'سورة $surahName • الآيات ($_startAyah - $_endAyah)');

    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: EdgeInsets.all(kIsWeb ? 16 : 14.r),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: theme.borderColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Quran Text rendered using QCF Page Fonts inside app
          _isLoadingText
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: CupertinoActivityIndicator(
                    color: theme.accentColor,
                    radius: 12.r,
                  ),
                )
              : Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text.rich(
                    TextSpan(
                      style: _getDynamicVerseTextStyle(
                        hasQcfFont: _qcfSpans.isNotEmpty,
                        verseText: _verseTextUthmani,
                        theme: theme,
                      ),
                      children: _qcfSpans.isNotEmpty
                          ? _qcfSpans
                          : [
                              TextSpan(
                                text: '( $_verseTextUthmani )',
                                style: const TextStyle(fontFamily: 'Amiri'),
                              ),
                            ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

          // Tafsir section in text preview
          if (_includeTafsir) ...[
            SizedBox(height: 12.h),
            Container(
              width: MediaQuery.sizeOf(context).width,
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: theme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.25),
                ),
              ),
              child: _isLoadingTafsir
                  ? Center(
                      child: CupertinoActivityIndicator(
                        color: theme.accentColor,
                        radius: 8.r,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: isEn
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_stories_outlined,
                                size: kIsWeb ? 13 : 12.r,
                                color: theme.accentColor,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                l10n.verseCardTafsirBadge,
                                style: TextStyle(
                                  fontFamily: isEn ? null : 'Amiri',
                                  fontSize: kIsWeb ? 12 : 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: theme.accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 6.h),
                        MixedDirectionText(
                          text: _tafsirText.trim(),
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: kIsWeb ? 13 : 12.sp,
                            height: 1.6,
                            color: theme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ],

          // Translation section in text preview
          if (_includeTranslation) ...[
            SizedBox(height: 12.h),
            Container(
              width: MediaQuery.sizeOf(context).width,
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: theme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.25),
                ),
              ),
              child: _isLoadingTranslation
                  ? Center(
                      child: CupertinoActivityIndicator(
                        color: theme.accentColor,
                        radius: 8.r,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: isEn
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.translate_rounded,
                                size: kIsWeb ? 13 : 12.r,
                                color: theme.accentColor,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                l10n.verseCardTranslationBadge,
                                style: TextStyle(
                                  fontFamily: isEn ? null : 'Amiri',
                                  fontSize: kIsWeb ? 12 : 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: theme.accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 6.h),
                        MixedDirectionText(
                          text: _translationText.trim(),
                          style: TextStyle(
                            fontSize: kIsWeb ? 13 : 12.sp,
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                            color: theme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ],

          SizedBox(height: 12.h),

          // Surah Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              rangeText,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: kIsWeb ? 12 : 11.sp,
                fontWeight: FontWeight.bold,
                color: theme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPageCardWidget(BuildContext context) {
    final theme = _activeTheme;

    return Container(
      key: const ValueKey('full_page_card_preview'),
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(14.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── The exact Quran Page Screenshot with safe margins
          if (_isCapturingSnapshot || _pageSnapshot == null)
            Container(
              height: 380.h,
              alignment: Alignment.center,
              child: CupertinoActivityIndicator(
                color: theme.accentColor,
                radius: 14.r,
              ),
            )
          else
            Image.memory(
              _pageSnapshot!,
              fit: BoxFit.fitWidth,
              width: MediaQuery.sizeOf(context).width,
            ),

          SizedBox(height: 12.h),

          // ── App Name Watermark underneath
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_stories_rounded,
                size: 14.r,
                color: theme.accentColor,
              ),
              SizedBox(width: 6.w),
              Text(
                'تَـبَـتَّـلْ • Tabattal',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryTextColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    const isWeb = kIsWeb;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: isWeb || MediaQuery.sizeOf(context).width > 600
              ? BorderRadius.circular(20)
              : BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
      padding: EdgeInsets.only(
        left: isWeb ? 20 : 16.w,
        right: isWeb ? 20 : 16.w,
        top: isWeb ? 20 : 16.h,
        bottom: (isWeb ? 20 : 16.h) + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.verseCardTitle,
                style: TextStyle(
                  fontSize: isWeb ? 18 : 17.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                splashRadius: 20,
              ),
            ],
          ),

          const Divider(height: 1),
          SizedBox(height: isWeb ? 12 : 10.h),

          // Scrollable Card Preview
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Single outer RepaintBoundary for PNG capture (No duplicate GlobalKeys!)
                  RepaintBoundary(
                    key: _repaintKey,
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      sizeCurve: Curves.fastOutSlowIn,
                      firstCurve: Curves.easeOut,
                      secondCurve: Curves.easeIn,
                      crossFadeState: _selectedFormat == ShareFormat.text
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        child: _selectedFormat == ShareFormat.fullPage
                            ? _buildFullPageCardWidget(context)
                            : ClipRRect(
                                key: const ValueKey('image_card_preview'),
                                borderRadius: BorderRadius.circular(16.r),
                                child: _buildVerseCardContent(context),
                              ),
                      ),
                      secondChild: _buildTextPreviewWidget(context),
                    ),
                  ),

                  SizedBox(height: isWeb ? 16 : 14.h),

                  // Customization Controls
                  _buildControlsSection(context, l10n),

                  // Animated status banner inside sheet
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => SizeTransition(
                      sizeFactor: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: _statusMessage == null
                        ? const SizedBox.shrink()
                        : Container(
                            key: ValueKey(_statusMessage),
                            margin: EdgeInsets.only(top: 10.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: _isSuccessStatus
                                  ? AppColors.accentGold.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: _isSuccessStatus
                                    ? AppColors.accentGold.withValues(alpha: 0.5)
                                    : Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isSuccessStatus
                                      ? Icons.check_circle_rounded
                                      : Icons.info_outline_rounded,
                                  size: 18.r,
                                  color: _isSuccessStatus ? AppColors.accentGold : Colors.red,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    _statusMessage!,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _isSuccessStatus
                                          ? AppColors.textPrimary
                                          : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: isWeb ? 16 : 12.h),

          // Action Buttons: Image/FullPage Mode (Share & Save) vs Text Mode (Copy Text) with smooth transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: (_selectedFormat == ShareFormat.image || _selectedFormat == ShareFormat.fullPage)
                ? Row(
                    key: const ValueKey('image_action_buttons'),
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isSharing || _isSaving) ? null : _shareCard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGold,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.accentGold.withValues(alpha: 0.85),
                            disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
                            padding: EdgeInsets.symmetric(vertical: isWeb ? 14 : 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            elevation: 2,
                          ),
                          icon: _isSharing
                              ? CupertinoActivityIndicator(
                                  radius: isWeb ? 8 : 8.r,
                                  color: Colors.white,
                                )
                              : const Icon(Icons.share_rounded),
                          label: Text(
                            l10n.verseCardShareImage,
                            style: TextStyle(
                              fontSize: isWeb ? 15 : 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_isSaving || _isSharing) ? null : _saveCardImage,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentGold,
                            disabledForegroundColor: AppColors.accentGold.withValues(alpha: 0.85),
                            side: BorderSide(
                              color: AppColors.accentGold.withValues(
                                alpha: (_isSaving || _isSharing) ? 0.85 : 1.0,
                              ),
                              width: 1.5,
                            ),
                            padding: EdgeInsets.symmetric(vertical: isWeb ? 14 : 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          icon: _isSaving
                              ? CupertinoActivityIndicator(
                                  radius: isWeb ? 8 : 8.r,
                                  color: AppColors.accentGold,
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(
                            l10n.verseCardSaveImage,
                            style: TextStyle(
                              fontSize: isWeb ? 15 : 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    key: const ValueKey('text_action_buttons'),
                    width: MediaQuery.sizeOf(context).width,
                    child: ElevatedButton.icon(
                      onPressed: () => _copyTextToClipboard(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isWeb ? 14 : 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(
                        l10n.verseCardCopyText,
                        style: TextStyle(
                          fontSize: isWeb ? 15 : 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
    ),
  );
  }

  /// Dynamically computes optimal font size and line height based on exact character length
  TextStyle _getDynamicVerseTextStyle({
    required bool hasQcfFont,
    required String verseText,
    required VerseCardTheme theme,
  }) {
    const isWeb = kIsWeb;
    final int length = verseText.length;
    double fontSize;
    double lineHeight;

    if (length <= 100) {
      // Very short single verse or short 5-verse combination (e.g. Al-Kawthar / Al-Ikhlas)
      fontSize = hasQcfFont ? (isWeb ? 38 : 34.sp) : (isWeb ? 34 : 30.sp);
      lineHeight = 1.90;
    } else if (length <= 180) {
      // Short verses combination
      fontSize = hasQcfFont ? (isWeb ? 33 : 29.sp) : (isWeb ? 29 : 26.sp);
      lineHeight = 1.85;
    } else if (length <= 300) {
      // Medium-short verse range
      fontSize = hasQcfFont ? (isWeb ? 28 : 25.sp) : (isWeb ? 25 : 22.sp);
      lineHeight = 1.80;
    } else if (length <= 480) {
      // Medium verse range
      fontSize = hasQcfFont ? (isWeb ? 23 : 21.sp) : (isWeb ? 21 : 19.sp);
      lineHeight = 1.75;
    } else if (length <= 750) {
      // Long verse range (e.g. Baqarah 282)
      fontSize = hasQcfFont ? (isWeb ? 19 : 17.sp) : (isWeb ? 17 : 15.sp);
      lineHeight = 1.70;
    } else if (length <= 1050) {
      // Ultra-long multi-verse combination
      fontSize = hasQcfFont ? (isWeb ? 17 : 15.sp) : (isWeb ? 15 : 13.5.sp);
      lineHeight = 1.65;
    } else {
      // Massive multi-verse range (> 1050 chars)
      fontSize = hasQcfFont ? (isWeb ? 15 : 13.5.sp) : (isWeb ? 13.5 : 12.sp);
      lineHeight = 1.60;
    }

    return TextStyle(
      fontFamily: 'Amiri',
      fontSize: fontSize,
      height: lineHeight,
      fontWeight: hasQcfFont ? FontWeight.normal : FontWeight.bold,
      color: theme.primaryTextColor,
    );
  }

  /// Builds the visual Verse Card content inside RepaintBoundary using the exact QCF Page Font (1..604).
  Widget _buildVerseCardContent(BuildContext context) {
    final theme = _activeTheme;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahCleanName = isEn
        ? QuranMetadata.getSurahNameEnglish(_surahNumber)
        : QuranMetadata.getSurahName(_surahNumber);
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final bool showBismillah = _startAyah == 1 && _surahNumber != 9 && _surahNumber != 1;

    return Container(
      width: screenWidth,
      color: theme.backgroundColor,
      padding: EdgeInsets.all(kIsWeb ? 14 : 12.r),
      child: Container(
        width: screenWidth,
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(kIsWeb ? 16 : 16.r),
          border: Border.all(color: theme.borderColor, width: 1.5),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 20 : 16.w,
          vertical: kIsWeb ? 22 : 18.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Decorative Header (Bismillah for Ayah 1, Gold Line Accent for middle of Surah)
            if (showBismillah)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 1,
                    width: kIsWeb ? 35 : 30.w,
                    color: theme.accentColor.withValues(alpha: 0.6),
                  ),
                  SizedBox(width: kIsWeb ? 10 : 8.w),
                  Text(
                    'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: kIsWeb ? 15 : 14.sp,
                      color: theme.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: kIsWeb ? 10 : 8.w),
                  Container(
                    height: 1,
                    width: kIsWeb ? 35 : 30.w,
                    color: theme.accentColor.withValues(alpha: 0.6),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 1,
                    width: kIsWeb ? 45 : 38.w,
                    color: theme.accentColor.withValues(alpha: 0.4),
                  ),
                  SizedBox(width: kIsWeb ? 8 : 6.w),
                  Icon(
                    Icons.star_rate_rounded,
                    size: kIsWeb ? 11 : 10.r,
                    color: theme.accentColor.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: kIsWeb ? 8 : 6.w),
                  Container(
                    height: 1,
                    width: kIsWeb ? 45 : 38.w,
                    color: theme.accentColor.withValues(alpha: 0.4),
                  ),
                ],
              ),

            SizedBox(height: kIsWeb ? 18 : 14.h),

            // Quran Verse Text rendered using dynamic typography scaling & QCF font
            _isLoadingText
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: kIsWeb ? 20 : 16.h),
                    child: CupertinoActivityIndicator(
                      color: theme.accentColor,
                      radius: 12.r,
                    ),
                  )
                : Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text.rich(
                      TextSpan(
                        style: _getDynamicVerseTextStyle(
                          hasQcfFont: _qcfSpans.isNotEmpty,
                          verseText: _verseTextUthmani,
                          theme: theme,
                        ),
                        children: _qcfSpans.isNotEmpty
                            ? _qcfSpans
                            : [
                                TextSpan(
                                  text: '﴿ $_verseTextUthmani ﴾',
                                  style: const TextStyle(fontFamily: 'Amiri'),
                                ),
                              ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

            SizedBox(height: kIsWeb ? 16 : 14.h),

            // Surah Name Badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 14 : 12.w,
                vertical: kIsWeb ? 5 : 4.h,
              ),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                _startAyah == _endAyah
                    ? (isEn ? 'Surah $surahCleanName • Ayah $_startAyah' : 'سورة $surahCleanName • الآية $_startAyah')
                    : (isEn ? 'Surah $surahCleanName • Ayahs $_startAyah-$_endAyah' : 'سورة $surahCleanName • الآيات ($_startAyah - $_endAyah)'),
                style: TextStyle(
                  fontSize: kIsWeb ? 13 : 12.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor,
                ),
              ),
            ),

            // Optional Tafsir Box
            if (_includeTafsir) ...[
              SizedBox(height: kIsWeb ? 14 : 12.h),
              Container(
                width: screenWidth,
                padding: EdgeInsets.all(kIsWeb ? 14 : 12.r),
                decoration: BoxDecoration(
                  color: theme.cardBackground,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: theme.borderColor.withValues(alpha: 0.6),
                  ),
                ),
                child: _isLoadingTafsir
                    ? Center(
                        child: CupertinoActivityIndicator(
                          color: theme.accentColor,
                          radius: 8.r,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: isEn
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_stories_outlined,
                                  size: kIsWeb ? 13 : 12.r,
                                  color: theme.accentColor,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  l10n.verseCardTafsirBadge,
                                  style: TextStyle(
                                    fontFamily: isEn ? null : 'Amiri',
                                    fontSize: kIsWeb ? 12 : 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: theme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6.h),
                          MixedDirectionText(
                            text: _tafsirText.trim(),
                            style: TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: kIsWeb ? 13 : 12.sp,
                              height: 1.6,
                              color: theme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ],

            // Optional Translation Box
            if (_includeTranslation) ...[
              SizedBox(height: kIsWeb ? 14 : 12.h),
              Container(
                width: screenWidth,
                padding: EdgeInsets.all(kIsWeb ? 14 : 12.r),
                decoration: BoxDecoration(
                  color: theme.cardBackground,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: theme.borderColor.withValues(alpha: 0.6),
                  ),
                ),
                child: _isLoadingTranslation
                    ? Center(
                        child: CupertinoActivityIndicator(
                          color: theme.accentColor,
                          radius: 8.r,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: isEn
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.translate_rounded,
                                  size: kIsWeb ? 13 : 12.r,
                                  color: theme.accentColor,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  l10n.verseCardTranslationBadge,
                                  style: TextStyle(
                                    fontFamily: isEn ? null : 'Amiri',
                                    fontSize: kIsWeb ? 12 : 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: theme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6.h),
                          MixedDirectionText(
                            text: _translationText.trim(),
                            style: TextStyle(
                              fontSize: kIsWeb ? 13 : 12.sp,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                              color: theme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ],

            // Footer Branding Watermark
            SizedBox(height: kIsWeb ? 16 : 14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: kIsWeb ? 14 : 12.r,
                  color: theme.accentColor.withValues(alpha: 0.8),
                ),
                SizedBox(width: kIsWeb ? 8 : 6.w),
                Text(
                  'تَـبَـتَّـلْ',
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: kIsWeb ? 14 : 13.sp,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                    color: theme.secondaryTextColor.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  ' • ',
                  style: TextStyle(
                    fontSize: kIsWeb ? 12 : 11.sp,
                    color: theme.accentColor.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  'Tabattal',
                  style: TextStyle(
                    fontSize: kIsWeb ? 12 : 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: theme.secondaryTextColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOptionTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold : Colors.transparent,
          borderRadius: BorderRadius.circular(9.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14.r,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            SizedBox(width: 4.w),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds theme selector and custom toggle switches.
  Widget _buildControlsSection(BuildContext context, AppLocalizations l10n) {
    const isWeb = kIsWeb;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Share Format Selector (نوع المشاركة)
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.verseCardFormatLabel,
                style: TextStyle(
                  fontSize: isWeb ? 14 : 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                width: MediaQuery.sizeOf(context).width,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.4),
                  ),
                ),
                padding: EdgeInsets.all(3.r),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFormatOptionTile(
                        label: l10n.verseCardFormatImage,
                        icon: Icons.image_rounded,
                        isSelected: _selectedFormat == ShareFormat.image,
                        onTap: () {
                          if (_selectedFormat != ShareFormat.image) {
                            setState(() {
                              _selectedFormat = ShareFormat.image;
                              _statusMessage = null;
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: _buildFormatOptionTile(
                        label: l10n.verseCardFormatText,
                        icon: Icons.text_snippet_rounded,
                        isSelected: _selectedFormat == ShareFormat.text,
                        onTap: () {
                          if (_selectedFormat != ShareFormat.text) {
                            setState(() {
                              _selectedFormat = ShareFormat.text;
                              _statusMessage = null;
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: _buildFormatOptionTile(
                        label: l10n.verseCardFormatFullPage,
                        icon: Icons.menu_book_rounded,
                        isSelected: _selectedFormat == ShareFormat.fullPage,
                        onTap: () {
                          if (_selectedFormat != ShareFormat.fullPage) {
                            setState(() {
                              _selectedFormat = ShareFormat.fullPage;
                              _statusMessage = null;
                            });
                            _loadFullPageData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Theme Selector Header & Chips (Animated smoothly with AnimatedCrossFade)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.fastOutSlowIn,
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeIn,
          crossFadeState: (_selectedFormat == ShareFormat.image || _selectedFormat == ShareFormat.fullPage)
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.themeAppearanceTitle,
                style: TextStyle(
                  fontSize: isWeb ? 14 : 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: isWeb ? 8 : 6.h),
              SizedBox(
                height: 42.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: VerseCardTheme.themes.length,
                  separatorBuilder: (ctx, idx) => SizedBox(width: 8.w),
                  itemBuilder: (context, index) {
                    final t = VerseCardTheme.themes[index];
                    final isSelected = index == _selectedThemeIndex;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedThemeIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: t.backgroundColor,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected ? AppColors.accentGold : t.borderColor,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.accentGold.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                          ),
                        child: Row(
                          children: [
                            Container(
                              width: 14.r,
                              height: 14.r,
                              decoration: BoxDecoration(
                                color: t.accentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              t.getLocalizedName(context),
                              style: TextStyle(
                                fontSize: isWeb ? 13 : 12.sp,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: t.primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: isWeb ? 12 : 10.h),
            ],
          ),
          secondChild: const SizedBox.shrink(),
        ),

        // Verse Range Picker (تحديد نطاق الآيات)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.verseCardVerseRange,
                style: TextStyle(
                  fontSize: isWeb ? 14 : 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  // From Ayah Tile
                  GestureDetector(
                    onTap: () => _showAyahPickerSheet(
                      context: context,
                      title: l10n.verseCardStartAyah,
                      currentValue: _startAyah,
                      options: List.generate(_totalAyahsInSurah, (i) => i + 1),
                      onSelected: (newStart) {
                        if (newStart == _startAyah) return;
                        final maxEndForNewStart = _getMaxEndAyah(newStart);
                        setState(() {
                          _startAyah = newStart;
                          if (_endAyah < _startAyah) {
                            _endAyah = _startAyah;
                          } else if (_endAyah > maxEndForNewStart) {
                            _endAyah = maxEndForNewStart;
                          }
                        });
                        _loadAllVerseData();
                      },
                    ),
                    child: Container(
                      height: 34.h,
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      decoration: BoxDecoration(
                        color: AppColors.cardCream,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGold.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEn ? 'Ayah $_startAyah' : 'آية $_startAyah',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.accentGold,
                            size: 18.r,
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                    child: Text(
                      isEn ? 'to' : 'إلى',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  // To Ayah Tile
                  GestureDetector(
                    onTap: () => _showAyahPickerSheet(
                      context: context,
                      title: l10n.verseCardEndAyah,
                      currentValue: _endAyah,
                      options: List.generate(
                        _getMaxEndAyah(_startAyah) - _startAyah + 1,
                        (i) => _startAyah + i,
                      ),
                      onSelected: (newEnd) {
                        if (newEnd == _endAyah) return;
                        setState(() {
                          _endAyah = newEnd;
                        });
                        _loadAllVerseData();
                      },
                    ),
                    child: Container(
                      height: 34.h,
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      decoration: BoxDecoration(
                        color: AppColors.cardCream,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGold.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEn ? 'Ayah $_endAyah' : 'آية $_endAyah',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.accentGold,
                            size: 18.r,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Always-Available Separate Tafsir Toggle Switch
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 18.r,
                    color: AppColors.accentGold,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    l10n.verseCardIncludeTafsir,
                    style: TextStyle(
                      fontSize: isWeb ? 14 : 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Switch(
                activeTrackColor: AppColors.accentGold,
                value: _includeTafsir,
                onChanged: (val) => setState(() => _includeTafsir = val),
              ),
            ],
          ),
        ),

        // Always-Available Separate Translation Toggle Switch
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.translate_rounded,
                    size: 18.r,
                    color: AppColors.accentGold,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    l10n.verseCardIncludeTranslation,
                    style: TextStyle(
                      fontSize: isWeb ? 14 : 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Switch(
                activeTrackColor: AppColors.accentGold,
                value: _includeTranslation,
                onChanged: (val) => setState(() => _includeTranslation = val),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

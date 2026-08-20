import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/arabic_text_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/bloc/settings_bloc.dart';
import '../../data/models/verse_model.dart';

import 'verse_card/helpers/verse_card_text_utils.dart';
import 'verse_card/models/verse_card_theme.dart';
import 'verse_card/services/verse_card_image_exporter.dart';
import 'verse_card/widgets/verse_card_action_buttons.dart';
import 'verse_card/widgets/verse_card_content_preview.dart';
import 'verse_card/widgets/verse_card_format_selector.dart';
import 'verse_card/widgets/verse_card_full_page_preview.dart';
import 'verse_card/widgets/verse_card_options_bar.dart';
import 'verse_card/widgets/verse_card_range_picker.dart';
import 'verse_card/widgets/verse_card_text_preview.dart';
import 'verse_card/widgets/verse_card_theme_selector.dart';

// Re-export models for external consumers
export 'verse_card/models/verse_card_theme.dart';

/// Shows the Verse Card Generator modal.
void showVerseCardGeneratorModal(
  BuildContext context, {
  required VerseModel verse,
  String? tafsirText,
  String? translationText,
  GlobalKey? pageRepaintKey,
  int? pageNumber,
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
            pageNumber: pageNumber,
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
          pageNumber: pageNumber,
        ),
      ),
    );
  }
}

class VerseCardGeneratorSheet extends StatefulWidget {
  final VerseModel verse;
  final String? tafsirText;
  final String? translationText;
  final GlobalKey? pageRepaintKey;
  final int? pageNumber;

  const VerseCardGeneratorSheet({
    super.key,
    required this.verse,
    this.tafsirText,
    this.translationText,
    this.pageRepaintKey,
    this.pageNumber,
  });

  @override
  State<VerseCardGeneratorSheet> createState() =>
      _VerseCardGeneratorSheetState();
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
  bool _isLoadingText = false;
  String _tafsirText = '';
  String _translationText = '';
  bool _isLoadingTafsir = false;
  bool _isLoadingTranslation = false;

  Uint8List? _pageSnapshot;
  bool _isCapturingSnapshot = false;
  String? _statusMessage;
  bool _isSuccessStatus = true;
  List<TextSpan> _qcfSpans = [];

  VerseCardTheme get _activeTheme => VerseCardTheme.themes[_selectedThemeIndex];
  int get _surahNumber =>
      int.tryParse(widget.verse.verseKey.split(':')[0]) ?? 1;

  @override
  void initState() {
    super.initState();
    _selectedThemeIndex = _getInitialThemeIndex();
    _startAyah = widget.verse.verseNumber;
    _endAyah = widget.verse.verseNumber;
    _totalAyahsInSurah = QuranMetadata.getVerseCountForSurah(_surahNumber);

    final cleanVerseText = VerseCardTextUtils.cleanTextForSharing(
      widget.verse.textUthmani,
    );
    final arabicAyahNum = VerseCardTextUtils.toArabicDigits(
      widget.verse.verseNumber,
    );
    _verseTextUthmani = '$cleanVerseText ﴿$arabicAyahNum﴾';

    final pageNum = widget.pageNumber;
    if (pageNum != null && widget.verse.words.isNotEmpty) {
      final pageStr = pageNum.toString().padLeft(3, '0');
      final fontFamily = 'QCF_P$pageStr';
      final codeText = widget.verse.words
          .map((w) => w.code.isNotEmpty ? w.code : w.textUthmani)
          .join(' ');
      _qcfSpans = [
        TextSpan(text: codeText, style: TextStyle(fontFamily: fontFamily)),
      ];
      _isLoadingText = false;
    } else {
      _isLoadingText = false;
      _loadVerseTextAndFont(null);
    }

    if (widget.tafsirText != null && widget.tafsirText!.trim().isNotEmpty) {
      _tafsirText = ArabicTextUtils.cleanTafsirOrHtml(
        widget.tafsirText!.trim(),
      );
      _includeTafsir = true;
    }
    if (widget.translationText != null &&
        widget.translationText!.trim().isNotEmpty) {
      _translationText = ArabicTextUtils.cleanTafsirOrHtml(
        widget.translationText!.trim(),
      );
      _includeTranslation = true;
    }
  }

  int _getInitialThemeIndex() {
    try {
      final settingsState = context.read<SettingsBloc>().state;
      final activeThemeId = settingsState.effectiveMushafTheme.id;
      final String targetName = switch (activeThemeId) {
        'white' => 'أبيض',
        'parchment' => 'عتيق',
        'roseGold' => 'روز جولد',
        'mint' => 'نعناعي',
        'olive' => 'زيتوني',
        'iceBlue' => 'ثلجي',
        'slate' => 'رخامي',
        'emerald' => 'زمردي',
        'burgundy' => 'عنابي',
        'dark' => 'ليلي',
        _ => 'كريمي',
      };
      final idx = VerseCardTheme.themes.indexWhere((t) => t.name == targetName);
      return idx != -1 ? idx : 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToStatusBanner() {
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

  Future<void> _loadAllVerseData() async {
    setState(() {
      _isLoadingText = true;
      if (_includeTafsir) _isLoadingTafsir = true;
      if (_includeTranslation) _isLoadingTranslation = true;
    });

    try {
      final db = await DatabaseHelper().database;
      final futures = <Future>[_loadVerseTextAndFont(db)];
      if (_includeTafsir) futures.add(_loadTafsirForRange(db));
      if (_includeTranslation) futures.add(_loadTranslationForRange(db));
      await Future.wait(futures);
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

  Future<void> _loadVerseTextAndFont(Database? database) async {
    try {
      final db = database ?? await DatabaseHelper().database;
      final verseKeys = List.generate(
        _endAyah - _startAyah + 1,
        (i) => '$_surahNumber:${_startAyah + i}',
      );

      final placeholders = List.filled(verseKeys.length, '?').join(',');
      final maps = await db.query(
        'quran_words',
        columns: [
          'code_v2',
          'page',
          'text_uthmani',
          'char_type_name',
          'verse_key',
        ],
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
          m['verse_key'] as String: m['text_uthmani'] as String,
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
            final codeText = wordsForVerse
                .map(
                  (m) =>
                      (m['code_v2'] as String?) ??
                      (m['text_uthmani'] as String),
                )
                .join(' ');

            if (newSpans.isNotEmpty) {
              newSpans.add(const TextSpan(text: ' '));
            }
            newSpans.add(
              TextSpan(
                text: codeText,
                style: TextStyle(fontFamily: fontFamily),
              ),
            );

            final rawTextWords =
                searchMap[vk] ??
                wordsForVerse
                    .where((m) => m['char_type_name'] == 'word')
                    .map((m) => m['text_uthmani'] as String)
                    .join(' ');

            final cleanVerseText = VerseCardTextUtils.cleanTextForSharing(
              rawTextWords,
            );
            final arabicAyahNum = VerseCardTextUtils.toArabicDigits(
              currentAyahNum,
            );
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

      final fallbackList = <String>[];
      for (int i = 0; i < searchMaps.length; i++) {
        final text = searchMaps[i]['text_uthmani'] as String;
        final currentAyahNum = _startAyah + i;
        final cleanText = VerseCardTextUtils.cleanTextForSharing(text);
        final arabicAyahNum = VerseCardTextUtils.toArabicDigits(currentAyahNum);
        fallbackList.add('$cleanText ﴿$arabicAyahNum﴾');
      }

      final fallbackText = fallbackList.isNotEmpty
          ? fallbackList.join(' ')
          : '${VerseCardTextUtils.cleanTextForSharing(widget.verse.textUthmani)} ﴿${VerseCardTextUtils.toArabicDigits(widget.verse.verseNumber)}﴾';

      if (mounted) {
        setState(() {
          _qcfSpans = [];
          _verseTextUthmani = fallbackText;
          _isLoadingText = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingText = false);
    }
  }

  Future<void> _loadTafsirForRange(Database db) async {
    try {
      final verseKeys = List.generate(
        _endAyah - _startAyah + 1,
        (i) => '$_surahNumber:${_startAyah + i}',
      );
      final placeholders = List.filled(verseKeys.length, '?').join(',');

      final List<Map<String, dynamic>> maps = await db.query(
        'tafsir',
        columns: ['verse_key', 'text'],
        where: 'verse_key IN ($placeholders) AND resource_id = ?',
        whereArgs: [...verseKeys, 16],
      );

      if (maps.isEmpty) {
        if (mounted) {
          setState(() {
            _tafsirText = ArabicTextUtils.cleanTafsirOrHtml(
              widget.tafsirText ?? '',
            );
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
          _tafsirText = ArabicTextUtils.cleanTafsirOrHtml(
            widget.tafsirText ?? '',
          );
          _isLoadingTafsir = false;
        });
      }
    }
  }

  Future<void> _loadTranslationForRange(Database db) async {
    try {
      final verseKeys = List.generate(
        _endAyah - _startAyah + 1,
        (i) => '$_surahNumber:${_startAyah + i}',
      );
      final placeholders = List.filled(verseKeys.length, '?').join(',');

      final List<Map<String, dynamic>> maps = await db.query(
        'translation',
        columns: ['verse_key', 'text'],
        where: 'verse_key IN ($placeholders) AND resource_id = ?',
        whereArgs: [...verseKeys, 20],
      );

      if (maps.isEmpty) {
        if (mounted) {
          setState(() {
            _translationText = ArabicTextUtils.cleanTafsirOrHtml(
              widget.translationText ?? '',
            );
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
          _translationText = ArabicTextUtils.cleanTafsirOrHtml(
            widget.translationText ?? '',
          );
          _isLoadingTranslation = false;
        });
      }
    }
  }

  Future<void> _loadFullPageData() async {
    if (_isCapturingSnapshot) return;
    setState(() => _isCapturingSnapshot = true);

    try {
      final key =
          widget.pageRepaintKey ?? QuranPageRepaintRegistry.currentPageKey;
      if (key == null) {
        if (mounted) setState(() => _isCapturingSnapshot = false);
        return;
      }

      Uint8List? capturedBytes;
      for (int attempt = 0; attempt < 3; attempt++) {
        await Future.delayed(Duration(milliseconds: 60 + (attempt * 60)));
        final bytes = await VerseCardImageExporter.captureCardPng(
          repaintKey: key,
          backgroundColor: _activeTheme.backgroundColor,
        );
        if (bytes != null) {
          capturedBytes = bytes;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _pageSnapshot = capturedBytes;
          _isCapturingSnapshot = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCapturingSnapshot = false);
    }
  }

  Future<void> _shareCard() async {
    if (_isSharing || _isSaving) return;
    setState(() {
      _isSharing = true;
      _statusMessage = null;
    });

    try {
      final imageBytes = await VerseCardImageExporter.captureCardPng(
        repaintKey: _repaintKey,
        backgroundColor: _activeTheme.backgroundColor,
      );
      if (imageBytes == null || !mounted) {
        if (mounted) setState(() => _isSharing = false);
        return;
      }

      await VerseCardImageExporter.shareCard(
        context: context,
        imageBytes: imageBytes,
        surahNumber: _surahNumber,
        startAyah: _startAyah,
        endAyah: _endAyah,
        fallbackText: _verseTextUthmani,
      );
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

  Future<void> _saveCardImage() async {
    if (_isSaving || _isSharing) return;
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final imageBytes = await VerseCardImageExporter.captureCardPng(
        repaintKey: _repaintKey,
        backgroundColor: _activeTheme.backgroundColor,
      );
      if (imageBytes == null || !mounted) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      final success = await VerseCardImageExporter.saveCardImage(
        imageBytes: imageBytes,
        surahNumber: _surahNumber,
        startAyah: _startAyah,
        endAyah: _endAyah,
      );

      if (mounted) {
        setState(() {
          _statusMessage = success
              ? 'تم حفظ الصورة في المعرض بنجاح'
              : 'خطأ أثناء حفظ الصورة';
          _isSuccessStatus = success;
        });
        _scrollToStatusBanner();
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

  Future<void> _copyTextToClipboard(BuildContext context) async {
    final text = VerseCardImageExporter.getFormattedShareText(
      context: context,
      surahNumber: _surahNumber,
      startAyah: _startAyah,
      endAyah: _endAyah,
      verseTextUthmani: _verseTextUthmani,
      includeTafsir: _includeTafsir,
      tafsirText: _tafsirText,
      includeTranslation: _includeTranslation,
      translationText: _translationText,
    );
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
              Flexible(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
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
                                ? VerseCardFullPagePreview(
                                    theme: _activeTheme,
                                    isCapturingSnapshot: _isCapturingSnapshot,
                                    pageSnapshot: _pageSnapshot,
                                    onRetryCapture: _loadFullPageData,
                                  )
                                : ClipRRect(
                                    key: const ValueKey('image_card_preview'),
                                    borderRadius: BorderRadius.circular(16.r),
                                    child: VerseCardContentPreview(
                                      theme: _activeTheme,
                                      surahNumber: _surahNumber,
                                      startAyah: _startAyah,
                                      endAyah: _endAyah,
                                      verseTextUthmani: _verseTextUthmani,
                                      qcfSpans: _qcfSpans,
                                      isLoadingText: _isLoadingText,
                                      includeTafsir: _includeTafsir,
                                      tafsirText: _tafsirText,
                                      isLoadingTafsir: _isLoadingTafsir,
                                      includeTranslation: _includeTranslation,
                                      translationText: _translationText,
                                      isLoadingTranslation:
                                          _isLoadingTranslation,
                                    ),
                                  ),
                          ),
                          secondChild: VerseCardTextPreview(
                            theme: _activeTheme,
                            surahNumber: _surahNumber,
                            startAyah: _startAyah,
                            endAyah: _endAyah,
                            verseTextUthmani: _verseTextUthmani,
                            qcfSpans: _qcfSpans,
                            isLoadingText: _isLoadingText,
                            includeTafsir: _includeTafsir,
                            tafsirText: _tafsirText,
                            isLoadingTafsir: _isLoadingTafsir,
                            includeTranslation: _includeTranslation,
                            translationText: _translationText,
                            isLoadingTranslation: _isLoadingTranslation,
                          ),
                        ),
                      ),
                      SizedBox(height: isWeb ? 16 : 14.h),
                      VerseCardFormatSelector(
                        selectedFormat: _selectedFormat,
                        onFormatChanged: (newFormat) {
                          if (_selectedFormat != newFormat) {
                            setState(() {
                              _selectedFormat = newFormat;
                              _statusMessage = null;
                            });
                            if (newFormat == ShareFormat.fullPage) {
                              _loadFullPageData();
                            }
                          }
                        },
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        sizeCurve: Curves.fastOutSlowIn,
                        firstCurve: Curves.easeOut,
                        secondCurve: Curves.easeIn,
                        crossFadeState:
                            (_selectedFormat == ShareFormat.image ||
                                _selectedFormat == ShareFormat.fullPage)
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: VerseCardThemeSelector(
                          selectedThemeIndex: _selectedThemeIndex,
                          onThemeSelected: (index) =>
                              setState(() => _selectedThemeIndex = index),
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        sizeCurve: Curves.fastOutSlowIn,
                        firstCurve: Curves.easeOut,
                        secondCurve: Curves.easeIn,
                        crossFadeState: _selectedFormat != ShareFormat.fullPage
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: VerseCardRangePicker(
                          startAyah: _startAyah,
                          endAyah: _endAyah,
                          totalAyahsInSurah: _totalAyahsInSurah,
                          onStartAyahChanged: (newStart) {
                            if (newStart == _startAyah) return;
                            final maxEnd = (newStart + 24).clamp(
                              1,
                              _totalAyahsInSurah,
                            );
                            setState(() {
                              _startAyah = newStart;
                              if (_endAyah < _startAyah) {
                                _endAyah = _startAyah;
                              } else if (_endAyah > maxEnd) {
                                _endAyah = maxEnd;
                              }
                            });
                            _loadAllVerseData();
                          },
                          onEndAyahChanged: (newEnd) {
                            if (newEnd == _endAyah) return;
                            setState(() => _endAyah = newEnd);
                            _loadAllVerseData();
                          },
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                      SizedBox(height: isWeb ? 8 : 6.h),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        sizeCurve: Curves.fastOutSlowIn,
                        firstCurve: Curves.easeOut,
                        secondCurve: Curves.easeIn,
                        crossFadeState: _selectedFormat != ShareFormat.fullPage
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: VerseCardOptionsBar(
                          includeTafsir: _includeTafsir,
                          onToggleTafsir: (val) {
                            setState(() {
                              _includeTafsir = val;
                              _statusMessage = null;
                            });
                            if (val && _tafsirText.isEmpty) {
                              _loadAllVerseData();
                            }
                          },
                          includeTranslation: _includeTranslation,
                          onToggleTranslation: (val) {
                            setState(() {
                              _includeTranslation = val;
                              _statusMessage = null;
                            });
                            if (val && _translationText.isEmpty) {
                              _loadAllVerseData();
                            }
                          },
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isWeb ? 16 : 12.h),
              VerseCardActionButtons(
                selectedFormat: _selectedFormat,
                isSharing: _isSharing,
                isSaving: _isSaving,
                onShare: _shareCard,
                onSave: _saveCardImage,
                onCopyText: () => _copyTextToClipboard(context),
                statusMessage: _statusMessage,
                isSuccessStatus: _isSuccessStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

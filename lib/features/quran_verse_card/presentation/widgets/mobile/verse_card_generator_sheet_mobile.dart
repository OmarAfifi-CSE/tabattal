import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../core/database/database_helper.dart';
import '../../../../../core/services/quran_font_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../../quran_audio/presentation/bloc/audio_bloc.dart';
import '../../../../quran_audio/presentation/bloc/audio_event.dart';
import '../../../../quran_reader/data/models/verse_model.dart';

import '../../../../quran_video_studio/data/repositories/video_studio_repository_impl.dart';
import '../../../../quran_video_studio/data/services/video_export_service.dart';
import '../../../../quran_video_studio/domain/entities/video_enums.dart';
import '../../../../quran_video_studio/domain/entities/video_project_config.dart';
import '../../../../quran_video_studio/presentation/bloc/video_studio_bloc.dart';
import '../../../../quran_video_studio/presentation/bloc/video_studio_event.dart';
import '../../../../quran_video_studio/presentation/bloc/video_studio_state.dart';
import '../../../../quran_video_studio/presentation/widgets/mobile/video_aspect_ratio_bar_mobile.dart';
import '../../../../quran_video_studio/presentation/widgets/mobile/video_background_selector_mobile.dart';
import '../../../../quran_video_studio/presentation/widgets/shared/video_export_progress_dialog.dart';
import '../../../../quran_video_studio/presentation/widgets/shared/video_fullscreen_preview_modal.dart';
import '../../../../quran_video_studio/presentation/widgets/mobile/video_options_selector_mobile.dart';
import '../../../../quran_video_studio/presentation/widgets/shared/video_preview_viewport.dart';
import '../../../../quran_video_studio/presentation/widgets/mobile/video_range_picker_mobile.dart';
import '../../../../quran_video_studio/presentation/widgets/mobile/video_reciter_selector_mobile.dart';
import '../../../../quran_video_studio/presentation/widgets/mobile/video_theme_selector_mobile.dart';

import '../shared/helpers/verse_card_text_utils.dart';
import '../shared/models/verse_card_theme.dart';
import '../shared/services/verse_card_image_exporter.dart';
import '../shared/widgets/verse_card_action_buttons.dart';
import '../shared/widgets/verse_card_content_preview.dart';
import '../shared/widgets/verse_card_format_selector.dart';
import '../shared/widgets/verse_card_full_page_preview.dart';
import '../shared/widgets/verse_card_options_bar.dart';
import '../shared/widgets/verse_card_range_picker.dart';
import '../shared/widgets/verse_card_text_preview.dart';
import '../shared/widgets/verse_card_theme_selector.dart';

// Re-export models for external consumers
export '../shared/models/verse_card_theme.dart';

/// Shows the unified Verse Card & Video Generator modal (Mobile).
void showVerseCardGeneratorModalMobile(
  BuildContext context, {
  required VerseModel verse,
  String? tafsirText,
  String? translationText,
  GlobalKey? pageRepaintKey,
  int? pageNumber,
  ShareFormat initialFormat = ShareFormat.video,
  List<VerseModel>? initialVerses,
}) {
  try {
    context.read<AudioBloc>().add(const PauseAudio());
  } catch (_) {}

  final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.90;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardCream,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
    ),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: VerseCardGeneratorSheetMobile(
        verse: verse,
        tafsirText: tafsirText,
        translationText: translationText,
        pageRepaintKey: pageRepaintKey,
        pageNumber: pageNumber,
        initialFormat: initialFormat,
        initialVerses: initialVerses,
      ),
    ),
  );
}

class VerseCardGeneratorSheetMobile extends StatelessWidget {
  final VerseModel verse;
  final String? tafsirText;
  final String? translationText;
  final GlobalKey? pageRepaintKey;
  final int? pageNumber;
  final ShareFormat initialFormat;
  final List<VerseModel>? initialVerses;

  const VerseCardGeneratorSheetMobile({
    super.key,
    required this.verse,
    this.tafsirText,
    this.translationText,
    this.pageRepaintKey,
    this.pageNumber,
    this.initialFormat = ShareFormat.video,
    this.initialVerses,
  });

  @override
  Widget build(BuildContext context) {
    final surahNum = int.tryParse(verse.verseKey.split(':')[0]) ?? 1;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return BlocProvider(
      create: (context) => VideoStudioBloc(
        repository: VideoStudioRepositoryImpl(),
        initialConfig: VideoProjectConfig(
          surahNumber: surahNum,
          startAyah: verse.verseNumber,
          endAyah: verse.verseNumber,
          isEnglish: isEn,
        ),
      )..add(
          VideoStudioInitRequested(
            surahNumber: surahNum,
            startAyah: verse.verseNumber,
            endAyah: verse.verseNumber,
            verses: initialVerses ?? [verse],
          ),
        ),
      child: _VerseCardGeneratorSheetContentMobile(
        verse: verse,
        tafsirText: tafsirText,
        translationText: translationText,
        pageRepaintKey: pageRepaintKey,
        pageNumber: pageNumber,
        initialFormat: initialFormat,
      ),
    );
  }
}

class _VerseCardGeneratorSheetContentMobile extends StatefulWidget {
  final VerseModel verse;
  final String? tafsirText;
  final String? translationText;
  final GlobalKey? pageRepaintKey;
  final int? pageNumber;
  final ShareFormat initialFormat;

  const _VerseCardGeneratorSheetContentMobile({
    required this.verse,
    this.tafsirText,
    this.translationText,
    this.pageRepaintKey,
    this.pageNumber,
    required this.initialFormat,
  });

  @override
  State<_VerseCardGeneratorSheetContentMobile> createState() =>
      _VerseCardGeneratorSheetContentMobileState();
}

class _VerseCardGeneratorSheetContentMobileState
    extends State<_VerseCardGeneratorSheetContentMobile> {
  final GlobalKey _repaintKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  late int _startAyah;
  late int _endAyah;
  late int _totalAyahsInSurah;

  int _selectedThemeIndex = 0;
  bool _includeTafsir = false;
  bool _includeTranslation = false;
  late ShareFormat _selectedFormat;
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

  bool _isExportDialogOpen = false;
  BuildContext? _dialogContext;

  VerseCardTheme get _activeTheme => VerseCardTheme.themes[_selectedThemeIndex];
  int get _surahNumber =>
      int.tryParse(widget.verse.verseKey.split(':')[0]) ?? 1;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.initialFormat;
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
    if (kIsWeb && pageNum != null) {
      QuranFontService.ensurePageFontLoaded(pageNum).then((_) {
        if (mounted) setState(() {});
      });
    }
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
      final idx =
          VerseCardTheme.themes.indexWhere((t) => t.id == activeThemeId);
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

  void _clearStatusBanner() {
    if (_statusMessage != null) {
      setState(() => _statusMessage = null);
    }
  }

  void _dismissExportDialog() {
    if (_isExportDialogOpen &&
        _dialogContext != null &&
        _dialogContext!.mounted) {
      _isExportDialogOpen = false;
      Navigator.of(_dialogContext!, rootNavigator: true).pop();
      _dialogContext = null;
    }
  }

  void _showExportDialog(BuildContext context, VideoStudioBloc bloc) {
    if (_isExportDialogOpen) return;
    _isExportDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        _dialogContext = dialogCtx;
        return BlocProvider.value(
          value: bloc,
          child: BlocBuilder<VideoStudioBloc, VideoStudioState>(
            builder: (context, state) {
              return VideoExportProgressDialog(
                progress: state.exportProgress,
                onCancel: () {
                  _dismissExportDialog();
                  bloc.add(const VideoStudioExportCancelled());
                },
                onDismiss: () {
                  _dismissExportDialog();
                },
              );
            },
          ),
        );
      },
    ).then((_) {
      _isExportDialogOpen = false;
      _dialogContext = null;
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

      final safeStart = _startAyah <= _endAyah ? _startAyah : _endAyah;
      final safeEnd = _endAyah >= _startAyah ? _endAyah : _startAyah;

      final verseKeys = List.generate(
        safeEnd - safeStart + 1,
        (i) => '$_surahNumber:${safeStart + i}',
      );
      final placeholders = List.filled(verseKeys.length, '?').join(',');

      final searchMaps = await db.query(
        'quran_search',
        columns: ['verse_key', 'text_uthmani'],
        where: 'verse_key IN ($placeholders)',
        whereArgs: verseKeys,
      );

      final Map<String, String> searchMap = {
        for (final row in searchMaps)
          (row['verse_key'] as String?) ?? '':
              (row['text_uthmani'] as String?) ?? '',
      };

      final List<Map<String, dynamic>> wordsMaps = await db.query(
        'quran_words',
        columns: [
          'verse_key',
          'page',
          'code_v2',
          'text_uthmani',
          'char_type_name',
        ],
        where: 'verse_key IN ($placeholders)',
        whereArgs: verseKeys,
        orderBy: 'id ASC',
      );

      if (wordsMaps.isNotEmpty) {
        final Map<String, List<Map<String, dynamic>>> wordsByVerse = {};
        for (final row in wordsMaps) {
          final vk = (row['verse_key'] as String?) ?? '';
          wordsByVerse.putIfAbsent(vk, () => []).add(row);
        }

        final newSpans = <TextSpan>[];
        final verseUthmaniList = <String>[];

        for (int i = 0; i < verseKeys.length; i++) {
          final vk = verseKeys[i];
          final currentAyahNum = safeStart + i;
          final wordsForVerse = wordsByVerse[vk];

          if (wordsForVerse != null && wordsForVerse.isNotEmpty) {
            final pageNum = wordsForVerse.first['page'] as int? ?? 1;
            final pageStr = pageNum.toString().padLeft(3, '0');
            final fontFamily = 'QCF_P$pageStr';

            final codeText = wordsForVerse
                .map(
                  (m) =>
                      (m['code_v2'] as String?) ??
                      (m['text_uthmani'] as String?) ??
                      '',
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
                    .map((m) => (m['text_uthmani'] as String?) ?? '')
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
        final text = (searchMaps[i]['text_uthmani'] as String?) ?? '';
        final currentAyahNum = safeStart + i;
        final cleanText = VerseCardTextUtils.cleanTextForSharing(text);
        final arabicAyahNum = VerseCardTextUtils.toArabicDigits(currentAyahNum);
        fallbackList.add('$cleanText ﴿$arabicAyahNum﴾');
      }

      if (mounted) {
        setState(() {
          _qcfSpans = [];
          _verseTextUthmani = fallbackList.join(' ');
          _isLoadingText = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingText = false);
      }
    }
  }

  Future<void> _loadTafsirForRange(Database db) async {
    try {
      final safeStart = _startAyah <= _endAyah ? _startAyah : _endAyah;
      final safeEnd = _endAyah >= _startAyah ? _endAyah : _startAyah;

      final List<Map<String, dynamic>> maps = await db.query(
        'tafsir',
        columns: ['verse_key', 'text'],
        where: 'verse_key LIKE ? AND resource_id = ?',
        whereArgs: ['$_surahNumber:%', 16],
        orderBy: 'rowid ASC',
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
      final List<int> directAyahs = [];
      for (final row in maps) {
        final vk = (row['verse_key'] as String?) ?? '';
        final parts = vk.split(':');
        if (parts.length == 2) {
          final ayahNum = int.tryParse(parts[1]);
          final rawText = (row['text'] as String?)?.trim() ?? '';
          final cleanText = ArabicTextUtils.cleanTafsirOrHtml(rawText);
          if (ayahNum != null && cleanText.isNotEmpty) {
            tafsirMap[ayahNum] = cleanText;
            directAyahs.add(ayahNum);
          }
        }
      }
      directAyahs.sort();

      final List<String> resultSegments = [];
      String lastGroupText = '';

      for (int ayah = safeStart; ayah <= safeEnd; ayah++) {
        final rootAyah = directAyahs.isNotEmpty
            ? directAyahs.lastWhere(
                (a) => a <= ayah,
                orElse: () => ayah,
              )
            : ayah;

        final verseTafsir = tafsirMap[rootAyah] ?? '';

        if (verseTafsir.trim().isNotEmpty &&
            verseTafsir.trim() != lastGroupText.trim()) {
          resultSegments.add(verseTafsir.trim());
          lastGroupText = verseTafsir.trim();
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
      final safeStart = _startAyah <= _endAyah ? _startAyah : _endAyah;
      final safeEnd = _endAyah >= _startAyah ? _endAyah : _startAyah;

      final List<Map<String, dynamic>> maps = await db.query(
        'translation',
        columns: ['verse_key', 'text'],
        where: 'verse_key LIKE ? AND resource_id = ?',
        whereArgs: ['$_surahNumber:%', 20],
        orderBy: 'rowid ASC',
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
      final List<int> directAyahs = [];
      for (final row in maps) {
        final vk = (row['verse_key'] as String?) ?? '';
        final parts = vk.split(':');
        if (parts.length == 2) {
          final ayahNum = int.tryParse(parts[1]);
          final rawText = (row['text'] as String?)?.trim() ?? '';
          final cleanText = ArabicTextUtils.cleanTafsirOrHtml(rawText);
          if (ayahNum != null && cleanText.isNotEmpty) {
            translationMap[ayahNum] = cleanText;
            directAyahs.add(ayahNum);
          }
        }
      }
      directAyahs.sort();

      final List<String> resultSegments = [];
      String lastGroupText = '';

      for (int ayah = safeStart; ayah <= safeEnd; ayah++) {
        final rootAyah = directAyahs.isNotEmpty
            ? directAyahs.lastWhere(
                (a) => a <= ayah,
                orElse: () => ayah,
              )
            : ayah;

        final verseTranslation = translationMap[rootAyah] ?? '';

        if (verseTranslation.trim().isNotEmpty &&
            verseTranslation.trim() != lastGroupText.trim()) {
          resultSegments.add(verseTranslation.trim());
          lastGroupText = verseTranslation.trim();
        }
      }

      final combinedTranslation = resultSegments.isNotEmpty
          ? resultSegments.join('\n\n')
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
          _statusMessage =
              AppLocalizations.of(context)!.verseCardShareError(e.toString());
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
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _statusMessage = success
              ? l10n.verseCardImageSavedGallerySuccess
              : l10n.verseCardImageSavedGalleryError;
          _isSuccessStatus = success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage =
              AppLocalizations.of(context)!.verseCardSaveError(e.toString());
          _isSuccessStatus = false;
        });
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
    }
  }

  String _getDynamicSheetTitle(AppLocalizations l10n) {
    switch (_selectedFormat) {
      case ShareFormat.video:
        return l10n.videoStudioTitle;
      case ShareFormat.image:
        return l10n.verseCardTitleImage;
      case ShareFormat.text:
        return l10n.verseCardTitleText;
      case ShareFormat.fullPage:
        return l10n.verseCardTitleFullPage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.88;

    return BlocConsumer<VideoStudioBloc, VideoStudioState>(
      listener: (context, videoState) async {
        if (videoState.errorMessage != null && videoState.errorMessage!.isNotEmpty) {
          if (_isExportDialogOpen) {
            _dismissExportDialog();
          }
          if (mounted) {
            setState(() {
              _statusMessage = videoState.errorMessage;
              _isSuccessStatus = false;
            });
          }
        } else if (videoState.exportProgress.isRendering && !_isExportDialogOpen) {
          _showExportDialog(context, context.read<VideoStudioBloc>());
        } else if (videoState.exportProgress.isCompleted &&
            _isExportDialogOpen) {
          _dismissExportDialog();

          final outputPath = videoState.exportProgress.outputPath;
          if (outputPath != null && outputPath.isNotEmpty) {
            if (videoState.pendingExportAction == VideoExportAction.share) {
              await VideoExportService.shareOutput(
                filePath: outputPath,
                title: l10n.videoStudioShareCaption,
              );
            } else {
              final saved = await VideoExportService.saveToGallery(
                filePath: outputPath,
              );
              if (mounted) {
                setState(() {
                  _statusMessage = saved
                      ? l10n.videoStudioSavedSuccess
                      : l10n.videoStudioSavedError;
                  _isSuccessStatus = saved;
                });
              }
            }
          }
        }
      },
      builder: (context, videoState) {
        return Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                top: 16.h,
                bottom: bottomSafeArea + viewInsetsBottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          reverseDuration: const Duration(milliseconds: 140),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: AlignmentDirectional.centerStart,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            key: ValueKey(_selectedFormat),
                            child: Text(
                              _getDynamicSheetTitle(l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
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
                  SizedBox(height: 10.h),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      child: Column(
                        children: [
                          // ---------------- PREVIEW AREA ----------------
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                            alignment: Alignment.topCenter,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              reverseDuration: const Duration(milliseconds: 160),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.topCenter,
                                  children: <Widget>[
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: _buildPreviewArea(videoState),
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // ---------------- FORMAT SELECTOR ----------------
                          VerseCardFormatSelector(
                            selectedFormat: _selectedFormat,
                            onFormatChanged: (newFormat) {
                              if (_selectedFormat != newFormat) {
                                if (_selectedFormat == ShareFormat.video) {
                                  context
                                      .read<VideoStudioBloc>()
                                      .add(const VideoStudioPlaybackReset());
                                }
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

                          // ---------------- DYNAMIC OPTIONS PER FORMAT ----------------
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                            alignment: Alignment.topCenter,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              reverseDuration: const Duration(milliseconds: 160),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.topCenter,
                                  children: <Widget>[
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: _buildOptionsArea(videoState),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // ---------------- ACTION BUTTONS ----------------
                  VerseCardActionButtons(
                    selectedFormat: _selectedFormat,
                    isSharing: _isSharing,
                    isSaving: _isSaving,
                    isExportingVideo: videoState.exportProgress.isRendering,
                    onShare: _shareCard,
                    onSave: _saveCardImage,
                    onCopyText: () => _copyTextToClipboard(context),
                    onShareVideo: () {
                      final bloc = context.read<VideoStudioBloc>();
                      _showExportDialog(context, bloc);
                      bloc.add(
                        const VideoStudioExportStarted(
                          action: VideoExportAction.share,
                        ),
                      );
                    },
                    onSaveVideo: () {
                      final bloc = context.read<VideoStudioBloc>();
                      _showExportDialog(context, bloc);
                      bloc.add(
                        const VideoStudioExportStarted(
                          action: VideoExportAction.saveToGallery,
                        ),
                      );
                    },
                    statusMessage: _statusMessage,
                    isSuccessStatus: _isSuccessStatus,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewArea(VideoStudioState videoState) {
    switch (_selectedFormat) {
      case ShareFormat.video:
        return KeyedSubtree(
          key: const ValueKey('video_studio_preview'),
          child: VideoPreviewViewport(
            state: videoState,
            onTogglePlay: () {
              context
                  .read<VideoStudioBloc>()
                  .add(const VideoStudioPlaybackToggled());
            },
            onVerseIndexChanged: (index) {
              context
                  .read<VideoStudioBloc>()
                  .add(VideoStudioActiveVerseIndexChanged(index));
            },
            onOpenFullscreen: () {
              VideoFullscreenPreviewModal.show(context);
            },
          ),
        );

      case ShareFormat.image:
        return RepaintBoundary(
          key: _repaintKey,
          child: Container(
            key: const ValueKey('image_card_preview'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
            ),
            padding: EdgeInsets.symmetric(vertical: 4.h),
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
              isLoadingTranslation: _isLoadingTranslation,
            ),
          ),
        );

      case ShareFormat.text:
        return KeyedSubtree(
          key: const ValueKey('text_preview'),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: VerseCardTextPreview(
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
        );

      case ShareFormat.fullPage:
        return RepaintBoundary(
          key: _repaintKey,
          child: Container(
            key: const ValueKey('full_page_preview'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
            ),
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: VerseCardFullPagePreview(
              theme: _activeTheme,
              isCapturingSnapshot: _isCapturingSnapshot,
              pageSnapshot: _pageSnapshot,
              onRetryCapture: _loadFullPageData,
            ),
          ),
        );
    }
  }

  Widget _buildOptionsArea(VideoStudioState videoState) {
    final config = videoState.config;

    switch (_selectedFormat) {
      case ShareFormat.video:
        return Column(
          key: const ValueKey('video_options_group'),
          children: [
            VideoAspectRatioBarMobile(
              selectedRatio: config.aspectRatio,
              onRatioSelected: (ratio) {
                _clearStatusBanner();
                context
                    .read<VideoStudioBloc>()
                    .add(VideoStudioAspectRatioChanged(ratio));
              },
            ),
            VideoBackgroundSelectorMobile(
              config: config,
              onCustomImageChanged: (path) {
                _clearStatusBanner();
                context
                    .read<VideoStudioBloc>()
                    .add(VideoStudioCustomImageSelected(path));
              },
              onCustomVideoChanged: (path) {
                _clearStatusBanner();
                context
                    .read<VideoStudioBloc>()
                    .add(VideoStudioCustomVideoSelected(path));
              },
            ),
            SizedBox(height: 12.h),
            Builder(
              builder: (context) {
                final bool hasCustomMedia = config.hasCustomMedia;
                final bool showThemeSelector =
                    !hasCustomMedia || config.showCardFrame;

                return AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: showThemeSelector
                      ? Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: VideoThemeSelectorMobile(
                            selectedPreset: config.themePreset,
                            onThemeSelected: (theme) {
                              _clearStatusBanner();
                              context
                                  .read<VideoStudioBloc>()
                                  .add(VideoStudioThemeChanged(theme));
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
            VideoRangePickerMobile(
              surahNumber: config.surahNumber,
              startAyah: _startAyah,
              endAyah: _endAyah,
              onStartAyahChanged: (start) {
                if (start == _startAyah) return;
                _clearStatusBanner();
                final maxEnd = (start + 9).clamp(1, _totalAyahsInSurah);
                int newEnd = _endAyah;
                if (newEnd < start) {
                  newEnd = start;
                } else if (newEnd > maxEnd) {
                  newEnd = maxEnd;
                }
                setState(() {
                  _startAyah = start;
                  _endAyah = newEnd;
                });
                context.read<VideoStudioBloc>().add(
                      VideoStudioVerseRangeChanged(
                        startAyah: start,
                        endAyah: newEnd,
                      ),
                    );
                if (_selectedFormat != ShareFormat.video) {
                  _loadAllVerseData();
                }
              },
              onEndAyahChanged: (end) {
                if (end == _endAyah) return;
                _clearStatusBanner();
                int newStart = _startAyah;
                if (newStart > end) {
                  newStart = end;
                }
                setState(() {
                  _startAyah = newStart;
                  _endAyah = end;
                });
                context.read<VideoStudioBloc>().add(
                      VideoStudioVerseRangeChanged(
                        startAyah: newStart,
                        endAyah: end,
                      ),
                    );
                if (_selectedFormat != ShareFormat.video) {
                  _loadAllVerseData();
                }
              },
            ),
            SizedBox(height: 12.h),
            VideoReciterSelectorMobile(
              selectedReciter: config.reciterName,
              selectedCategory: config.reciterCategory,
              onReciterSelected: (name, category, path) {
                _clearStatusBanner();
                context.read<VideoStudioBloc>().add(
                      VideoStudioReciterChanged(
                        reciterName: name,
                        reciterCategory: category,
                        reciterPath: path,
                      ),
                    );
              },
            ),
            SizedBox(height: 12.h),
            VideoOptionsSelectorMobile(
              config: config,
              onDisplayModeChanged: (mode) {
                _clearStatusBanner();
                context
                    .read<VideoStudioBloc>()
                    .add(VideoStudioTextDisplayModeChanged(mode));
              },
              onQualityChanged: (quality) {
                _clearStatusBanner();
                context
                    .read<VideoStudioBloc>()
                    .add(VideoStudioQualityChanged(quality));
              },
              onToggleOption: ({
                showSurahBadge,
                showReciterName,
                showCardFrame,
                showTafsir,
                showEnglishTranslation,
                showAudioWaveform,
              }) {
                _clearStatusBanner();
                context.read<VideoStudioBloc>().add(
                      VideoStudioOptionToggled(
                        showSurahBadge: showSurahBadge,
                        showReciterName: showReciterName,
                        showCardFrame: showCardFrame,
                        showTafsir: showTafsir,
                        showEnglishTranslation: showEnglishTranslation,
                        showAudioWaveform: showAudioWaveform,
                      ),
                    );
              },
            ),
          ],
        );

      case ShareFormat.image:
        return Column(
          key: const ValueKey('image_options_group'),
          children: [
            VerseCardThemeSelector(
              selectedThemeIndex: _selectedThemeIndex,
              onThemeSelected: (index) =>
                  setState(() => _selectedThemeIndex = index),
            ),
            SizedBox(height: 8.h),
            VerseCardRangePicker(
              surahNumber: _surahNumber,
              startAyah: _startAyah,
              endAyah: _endAyah,
              totalAyahsInSurah: _totalAyahsInSurah,
              onStartAyahChanged: (newStart) {
                if (newStart == _startAyah) return;
                final maxEnd = (newStart + 24).clamp(1, _totalAyahsInSurah);
                int newEnd = _endAyah;
                if (newEnd < newStart) {
                  newEnd = newStart;
                } else if (newEnd > maxEnd) {
                  newEnd = maxEnd;
                }
                setState(() {
                  _startAyah = newStart;
                  _endAyah = newEnd;
                });
                context.read<VideoStudioBloc>().add(
                      VideoStudioVerseRangeChanged(
                        startAyah: newStart,
                        endAyah: newEnd,
                      ),
                    );
                _loadAllVerseData();
              },
              onEndAyahChanged: (newEnd) {
                if (newEnd == _endAyah) return;
                int newStart = _startAyah;
                if (newStart > newEnd) {
                  newStart = newEnd;
                }
                setState(() {
                  _startAyah = newStart;
                  _endAyah = newEnd;
                });
                context.read<VideoStudioBloc>().add(
                      VideoStudioVerseRangeChanged(
                        startAyah: newStart,
                        endAyah: newEnd,
                      ),
                    );
                _loadAllVerseData();
              },
            ),
            SizedBox(height: 6.h),
            VerseCardOptionsBar(
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
          ],
        );

      case ShareFormat.text:
        return Column(
          key: const ValueKey('text_options_group'),
          children: [
            VerseCardRangePicker(
              surahNumber: _surahNumber,
              startAyah: _startAyah,
              endAyah: _endAyah,
              totalAyahsInSurah: _totalAyahsInSurah,
              onStartAyahChanged: (newStart) {
                if (newStart == _startAyah) return;
                final maxEnd = (newStart + 24).clamp(1, _totalAyahsInSurah);
                int newEnd = _endAyah;
                if (newEnd < newStart) {
                  newEnd = newStart;
                } else if (newEnd > maxEnd) {
                  newEnd = maxEnd;
                }
                setState(() {
                  _startAyah = newStart;
                  _endAyah = newEnd;
                });
                context.read<VideoStudioBloc>().add(
                      VideoStudioVerseRangeChanged(
                        startAyah: newStart,
                        endAyah: newEnd,
                      ),
                    );
                _loadAllVerseData();
              },
              onEndAyahChanged: (newEnd) {
                if (newEnd == _endAyah) return;
                int newStart = _startAyah;
                if (newStart > newEnd) {
                  newStart = newEnd;
                }
                setState(() {
                  _startAyah = newStart;
                  _endAyah = newEnd;
                });
                context.read<VideoStudioBloc>().add(
                      VideoStudioVerseRangeChanged(
                        startAyah: newStart,
                        endAyah: newEnd,
                      ),
                    );
                _loadAllVerseData();
              },
            ),
            SizedBox(height: 6.h),
            VerseCardOptionsBar(
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
          ],
        );

      case ShareFormat.fullPage:
        return Column(
          key: const ValueKey('full_page_options_group'),
          children: [
            VerseCardThemeSelector(
              selectedThemeIndex: _selectedThemeIndex,
              onThemeSelected: (index) =>
                  setState(() => _selectedThemeIndex = index),
            ),
          ],
        );
    }
  }
}

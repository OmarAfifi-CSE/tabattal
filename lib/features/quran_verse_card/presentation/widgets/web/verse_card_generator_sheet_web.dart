import 'dart:async';
import 'package:flutter/cupertino.dart';
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
import '../../../../quran_video_studio/presentation/widgets/web/video_aspect_ratio_bar_web.dart';
import '../../../../quran_video_studio/presentation/widgets/shared/video_background_player_view.dart';
import '../../../../quran_video_studio/presentation/widgets/web/video_background_selector_web.dart';
import '../../../../quran_video_studio/presentation/widgets/shared/video_export_progress_dialog.dart';
import '../../../../quran_video_studio/presentation/widgets/shared/video_frame_painter.dart';
import '../../../../quran_video_studio/presentation/widgets/shared/video_fullscreen_preview_modal.dart';
import '../../../../quran_video_studio/presentation/widgets/web/video_options_selector_web.dart';
import '../../../../quran_video_studio/presentation/widgets/web/video_range_picker_web.dart';
import '../../../../quran_video_studio/presentation/widgets/web/video_reciter_selector_web.dart';
import '../../../../quran_video_studio/presentation/widgets/web/video_theme_selector_web.dart';

import '../shared/helpers/verse_card_text_utils.dart';
import '../shared/models/verse_card_theme.dart';
import '../shared/services/verse_card_image_exporter.dart';
import '../shared/widgets/verse_card_content_preview.dart';
import '../shared/widgets/verse_card_full_page_preview.dart';
import '../shared/widgets/verse_card_text_preview.dart';

// Re-export models for external consumers
export '../shared/models/verse_card_theme.dart';

/// Shows the dedicated Verse Card & Video Studio modal dialog for web.
void showVerseCardGeneratorModalWeb(
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

  final screenW = MediaQuery.sizeOf(context).width;
  final screenH = MediaQuery.sizeOf(context).height;
  final isLandscape = screenW > screenH;
  final maxDialogW = isLandscape
      ? (screenW * 0.96).clamp(880.0, 1180.0)
      : (screenW * 0.88).clamp(600.0, 720.0);
  final maxDialogH = isLandscape
      ? (screenH * 0.95).clamp(600.0, 820.0)
      : (screenH * 0.92).clamp(720.0, 940.0);

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: (isLandscape ? 12.0 : 20.0).w,
        vertical: (isLandscape ? 10.0 : 18.0).h,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxDialogW, maxHeight: maxDialogH),
        child: VerseCardGeneratorSheetWeb(
          verse: verse,
          tafsirText: tafsirText,
          translationText: translationText,
          pageRepaintKey: pageRepaintKey,
          pageNumber: pageNumber,
          initialFormat: initialFormat,
          initialVerses: initialVerses,
        ),
      ),
    ),
  );
}

class VerseCardGeneratorSheetWeb extends StatelessWidget {
  final VerseModel verse;
  final String? tafsirText;
  final String? translationText;
  final GlobalKey? pageRepaintKey;
  final int? pageNumber;
  final ShareFormat initialFormat;
  final List<VerseModel>? initialVerses;

  const VerseCardGeneratorSheetWeb({
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
      child: _VerseCardGeneratorSheetWebContent(
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

class _VerseCardGeneratorSheetWebContent extends StatefulWidget {
  final VerseModel verse;
  final String? tafsirText;
  final String? translationText;
  final GlobalKey? pageRepaintKey;
  final int? pageNumber;
  final ShareFormat initialFormat;

  const _VerseCardGeneratorSheetWebContent({
    required this.verse,
    this.tafsirText,
    this.translationText,
    this.pageRepaintKey,
    this.pageNumber,
    required this.initialFormat,
  });

  @override
  State<_VerseCardGeneratorSheetWebContent> createState() =>
      _VerseCardGeneratorSheetWebContentState();
}

class _VerseCardGeneratorSheetWebContentState
    extends State<_VerseCardGeneratorSheetWebContent> {
  final GlobalKey _repaintKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  late int _selectedThemeIndex;
  late int _startAyah;
  late int _endAyah;
  late int _totalAyahsInSurah;

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
    if (pageNum != null && widget.verse.words.isNotEmpty) {
      QuranFontService.ensurePageFontLoaded(pageNum).then((_) {
        if (mounted) setState(() {});
      });
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
            await QuranFontService.ensurePageFontLoaded(pageNum);
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
              ? l10n.verseCardImageDownloadedSuccess
              : l10n.verseCardImageDownloadedError;
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
    final size = MediaQuery.sizeOf(context);
    final screenW = size.width;
    final screenH = size.height;
    final maxSheetHeight = screenH * 0.92;

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
                      ? l10n.videoStudioDownloadedSuccess
                      : l10n.videoStudioDownloadedError;
                  _isSuccessStatus = saved;
                });
              }
            }
          }
        }
      },
      builder: (context, videoState) {
        final isLandscape = screenW > screenH;

        return Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardCream,
                borderRadius: BorderRadius.circular(isLandscape ? 16.0 : 20.r),
              ),
              padding: EdgeInsets.fromLTRB(
                isLandscape ? 18.0 : 22.w,
                isLandscape ? 12.0 : 14.h,
                isLandscape ? 18.0 : 22.w,
                isLandscape ? 16.0 : 22.h,
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
                                fontSize: isLandscape ? 18.0 : 22.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, size: isLandscape ? 22.0 : 26.sp),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  SizedBox(height: isLandscape ? 8.0 : 12.h),

                  if (isLandscape)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Column: Preview area + Video Player Controls
                          Expanded(
                            flex: 6,
                            child: Center(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: _buildPreviewArea(videoState, isLandscape: true),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14.0),
                          Container(
                            width: 1,
                            color: AppColors.divider,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          const SizedBox(width: 14.0),
                          // Right Column: Format Selector + Dynamic Options + Action Buttons
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      children: [
                                        _VerseCardFormatSelectorWeb(
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
                                        AnimatedSize(
                                          duration: const Duration(milliseconds: 280),
                                          curve: Curves.easeInOutCubic,
                                          alignment: Alignment.topCenter,
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 240),
                                            reverseDuration: const Duration(milliseconds: 160),
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            child: _buildOptionsArea(videoState),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: isLandscape ? 16.0 : 20.0),
                                _VerseCardActionButtonsWeb(
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
                        ],
                      ),
                    )
                  else
                    ...[
                      Flexible(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
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
                                  child: _buildPreviewArea(videoState, isLandscape: false),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // ---------------- FORMAT SELECTOR TABLET ----------------
                              _VerseCardFormatSelectorWeb(
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
                      const SizedBox(height: 20.0),

                      // ---------------- ACTION BUTTONS TABLET ----------------
                      _VerseCardActionButtonsWeb(
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewArea(VideoStudioState videoState, {bool isLandscape = false}) {
    switch (_selectedFormat) {
      case ShareFormat.video:
        return KeyedSubtree(
          key: const ValueKey('video_studio_preview_web'),
          child: _VideoPreviewViewportWeb(
            state: videoState,
            isLandscape: isLandscape,
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
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 12.0 : 16.0,
              vertical: isLandscape ? 8.0 : 12.0,
            ),
            child: Container(
              key: const ValueKey('image_card_preview_web'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
              ),
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
          ),
        );

      case ShareFormat.text:
        return KeyedSubtree(
          key: const ValueKey('text_preview_web'),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 12.0 : 16.0,
              vertical: isLandscape ? 8.0 : 12.0,
            ),
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
            key: const ValueKey('full_page_preview_web'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 12.0 : 16.0,
              vertical: isLandscape ? 8.0 : 12.0,
            ),
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
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    switch (_selectedFormat) {
      case ShareFormat.video:
        return Column(
          key: const ValueKey('video_options_group_web'),
          children: [
            VideoAspectRatioBarWeb(
              selectedRatio: config.aspectRatio,
              onRatioSelected: (ratio) {
                _clearStatusBanner();
                context
                    .read<VideoStudioBloc>()
                    .add(VideoStudioAspectRatioChanged(ratio));
              },
            ),
            VideoBackgroundSelectorWeb(
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
            SizedBox(height: isLandscape ? 12.0 : 14.0),
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
                          padding: EdgeInsets.only(
                            bottom: isLandscape ? 12.0 : 14.0,
                          ),
                          child: VideoThemeSelectorWeb(
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
            VideoRangePickerWeb(
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
            SizedBox(height: isLandscape ? 12.0 : 14.0),
            VideoReciterSelectorWeb(
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
            SizedBox(height: isLandscape ? 12.0 : 14.0),
            VideoOptionsSelectorWeb(
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
          key: const ValueKey('image_options_group_web'),
          children: [
            _VerseCardThemeSelectorWeb(
              selectedThemeIndex: _selectedThemeIndex,
              onThemeSelected: (index) {
                setState(() => _selectedThemeIndex = index);
              },
            ),
            SizedBox(height: isLandscape ? 14.0 : 16.0),
            _VerseCardRangePickerWeb(
              surahNumber: _surahNumber,
              startAyah: _startAyah,
              endAyah: _endAyah,
              totalAyahsInSurah: _totalAyahsInSurah,
              onStartAyahChanged: (start) {
                if (start == _startAyah) return;
                final maxEnd = (start + 24).clamp(1, _totalAyahsInSurah);
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
                _loadAllVerseData();
              },
              onEndAyahChanged: (end) {
                if (end == _endAyah) return;
                int newStart = _startAyah;
                if (newStart > end) {
                  newStart = end;
                }
                setState(() {
                  _startAyah = newStart;
                  _endAyah = end;
                });
                _loadAllVerseData();
              },
            ),
            SizedBox(height: isLandscape ? 14.0 : 16.0),
            _VerseCardOptionsBarWeb(
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
          key: const ValueKey('text_options_group_web'),
          children: [
            _VerseCardRangePickerWeb(
              surahNumber: _surahNumber,
              startAyah: _startAyah,
              endAyah: _endAyah,
              totalAyahsInSurah: _totalAyahsInSurah,
              onStartAyahChanged: (start) {
                if (start == _startAyah) return;
                final maxEnd = (start + 24).clamp(1, _totalAyahsInSurah);
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
                _loadAllVerseData();
              },
              onEndAyahChanged: (end) {
                if (end == _endAyah) return;
                int newStart = _startAyah;
                if (newStart > end) {
                  newStart = end;
                }
                setState(() {
                  _startAyah = newStart;
                  _endAyah = end;
                });
                _loadAllVerseData();
              },
            ),
            SizedBox(height: isLandscape ? 14.0 : 16.0),
            _VerseCardOptionsBarWeb(
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
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isLandscape ? 8.0 : 12.0),
          child: _VerseCardThemeSelectorWeb(
            selectedThemeIndex: _selectedThemeIndex,
            onThemeSelected: (index) {
              setState(() => _selectedThemeIndex = index);
            },
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📱 TABLET-SPECIFIC SUBWIDGETS WITH PROPER PADDING & TYPOGRAPHY
// ─────────────────────────────────────────────────────────────────────────────

class _VerseCardFormatSelectorWeb extends StatelessWidget {
  final ShareFormat selectedFormat;
  final ValueChanged<ShareFormat> onFormatChanged;

  const _VerseCardFormatSelectorWeb({
    required this.selectedFormat,
    required this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: isLandscape ? 14.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.verseCardFormatLabel,
            style: TextStyle(
              fontSize: isLandscape ? 15.0.sp : 17.5.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: isLandscape ? 8.0 : 10.0),
          Container(
            width: MediaQuery.sizeOf(context).width,
            decoration: BoxDecoration(
              color: AppColors.surfaceCream,
              borderRadius: BorderRadius.circular(isLandscape ? 12.0 : 16.0),
              border: Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            padding: EdgeInsets.all(isLandscape ? 5.0 : 6.0),
            child: Row(
              children: [
                Expanded(
                  child: _FormatTileWeb(
                    label: l10n.verseCardFormatVideo,
                    icon: Icons.videocam_rounded,
                    isSelected: selectedFormat == ShareFormat.video,
                    onTap: () => onFormatChanged(ShareFormat.video),
                  ),
                ),
                SizedBox(width: isLandscape ? 6.0 : 6.0),
                Expanded(
                  child: _FormatTileWeb(
                    label: l10n.verseCardFormatImage,
                    icon: Icons.image_rounded,
                    isSelected: selectedFormat == ShareFormat.image,
                    onTap: () => onFormatChanged(ShareFormat.image),
                  ),
                ),
                SizedBox(width: isLandscape ? 6.0 : 6.0),
                Expanded(
                  child: _FormatTileWeb(
                    label: l10n.verseCardFormatText,
                    icon: Icons.text_snippet_rounded,
                    isSelected: selectedFormat == ShareFormat.text,
                    onTap: () => onFormatChanged(ShareFormat.text),
                  ),
                ),
                SizedBox(width: isLandscape ? 6.0 : 6.0),
                Expanded(
                  child: _FormatTileWeb(
                    label: l10n.verseCardFormatFullPage,
                    icon: Icons.menu_book_rounded,
                    isSelected: selectedFormat == ShareFormat.fullPage,
                    onTap: () => onFormatChanged(ShareFormat.fullPage),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatTileWeb extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatTileWeb({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 8.0 : 10.0,
          vertical: isLandscape ? 10.0 : 12.0,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold : Colors.transparent,
          borderRadius: BorderRadius.circular(isLandscape ? 10.0 : 12.0),
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
              size: isLandscape ? 20.0 : 22.0,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            SizedBox(width: isLandscape ? 6.0 : 8.0),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: isLandscape ? 14.5 : 16.0,
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
}

class _VerseCardThemeSelectorWeb extends StatelessWidget {
  final int selectedThemeIndex;
  final ValueChanged<int> onThemeSelected;

  const _VerseCardThemeSelectorWeb({
    required this.selectedThemeIndex,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.videoStudioThemeAndColors,
          style: TextStyle(
            fontSize: isLandscape ? 15.0.sp : 16.0.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: isLandscape ? 6.0 : 8.0),
        SizedBox(
          height: isLandscape ? 44.0 : 46.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: VerseCardTheme.themes.length,
            separatorBuilder: (_, _) => SizedBox(width: isLandscape ? 8.0 : 10.0),
            itemBuilder: (context, index) {
              final t = VerseCardTheme.themes[index];
              final isSelected = index == selectedThemeIndex;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onThemeSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 14.0 : 16.0,
                      vertical: isLandscape ? 6.0 : 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: t.backgroundColor,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: isSelected ? AppColors.accentGold : t.borderColor,
                        width: isSelected ? 2.0 : 1.0,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14.0,
                          height: 14.0,
                          decoration: BoxDecoration(
                            color: t.accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: isLandscape ? 8.0 : 10.0),
                        Text(
                          t.getLocalizedName(context),
                          style: TextStyle(
                            fontSize: isLandscape ? 14.0.sp : 15.0.sp,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: t.primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VerseCardRangePickerWeb extends StatelessWidget {
  final int? surahNumber;
  final int startAyah;
  final int endAyah;
  final int totalAyahsInSurah;
  final ValueChanged<int> onStartAyahChanged;
  final ValueChanged<int> onEndAyahChanged;

  const _VerseCardRangePickerWeb({
    this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.totalAyahsInSurah,
    required this.onStartAyahChanged,
    required this.onEndAyahChanged,
  });

  int _getMaxEndAyah(int start) {
    return (start + 24).clamp(1, totalAyahsInSurah);
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
            constraints: const BoxConstraints(maxWidth: 420.0, maxHeight: 480.0),
            child: Directionality(
              textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17.0.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, size: 24.sp),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 10.0),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: 10.0,
                          mainAxisSpacing: 10.0,
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
                            borderRadius: BorderRadius.circular(12.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.accentGold
                                    : AppColors.accentGold
                                        .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12.0),
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
                                Localizations.localeOf(context).languageCode ==
                                        'en'
                                    ? '$ayah'
                                    : VerseCardTextUtils.toArabicDigits(ayah),
                                style: TextStyle(
                                  fontSize: 15.0.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
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
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

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
                fontSize: isLandscape ? 15.0.sp : 16.0.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (surahNumber != null) ...[
              SizedBox(width: isLandscape ? 8.0 : 10.0),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 10.0 : 12.0,
                  vertical: isLandscape ? 3.0 : 4.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: AppColors.accentGold.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Text(
                  l10n.verseCardSurah(
                    isEn
                        ? QuranMetadata.getSurahNameEnglish(surahNumber!)
                        : QuranMetadata.getSurahName(surahNumber!),
                  ),
                  style: TextStyle(
                    fontSize: isLandscape ? 13.0.sp : 14.0.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: isLandscape ? 6.0 : 8.0),
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
                    onSelected: onStartAyahChanged,
                  );
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: isLandscape ? 10.0 : 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.0),
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
                          l10n.verseCardFromAyah(
                            isEn
                                ? '$startAyah'
                                : VerseCardTextUtils.toArabicDigits(startAyah),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isLandscape ? 14.5 : 15.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: isLandscape ? 20.0 : 22.0,
                        color: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: isLandscape ? 8.0 : 10.0),
            Expanded(
              child: InkWell(
                onTap: () {
                  _showAyahPickerDialog(
                    context: context,
                    title: l10n.verseCardEndAyah,
                    currentValue: endAyah,
                    options: endOptions,
                    onSelected: onEndAyahChanged,
                  );
                },
                borderRadius: BorderRadius.circular(12.0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: isLandscape ? 10.0 : 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12.0),
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
                          l10n.verseCardToAyah(
                            isEn
                                ? '$endAyah'
                                : VerseCardTextUtils.toArabicDigits(endAyah),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isLandscape ? 14.5 : 15.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: isLandscape ? 20.0 : 22.0,
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

class _VerseCardOptionsBarWeb extends StatelessWidget {
  final bool includeTafsir;
  final ValueChanged<bool> onToggleTafsir;
  final bool includeTranslation;
  final ValueChanged<bool> onToggleTranslation;

  const _VerseCardOptionsBarWeb({
    required this.includeTafsir,
    required this.onToggleTafsir,
    required this.includeTranslation,
    required this.onToggleTranslation,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.videoStudioDisplayOptions,
          style: TextStyle(
            fontSize: isLandscape ? 15.0.sp : 16.0.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: isLandscape ? 6.0 : 8.0),
        Container(
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(isLandscape ? 12.0 : 14.0),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildSwitchRow(
                icon: Icons.menu_book_outlined,
                title: l10n.verseCardIncludeTafsir,
                value: includeTafsir,
                onChanged: onToggleTafsir,
                isLandscape: isLandscape,
              ),
              Divider(
                height: 1,
                indent: isLandscape ? 14.0 : 16.0,
                endIndent: isLandscape ? 14.0 : 16.0,
                color: AppColors.accentGold.withValues(alpha: 0.15),
              ),
              _buildSwitchRow(
                icon: Icons.g_translate_outlined,
                title: l10n.verseCardIncludeTranslation,
                value: includeTranslation,
                onChanged: onToggleTranslation,
                isLandscape: isLandscape,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isLandscape,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 14.0 : 16.0,
        vertical: isLandscape ? 6.0 : 8.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: isLandscape ? 20.0 : 22.0,
                color: AppColors.accentGold,
              ),
              SizedBox(width: isLandscape ? 10.0 : 12.0),
              Text(
                title,
                style: TextStyle(
                  fontSize: isLandscape ? 14.5 : 15.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accentGold,
            activeTrackColor: AppColors.accentGold.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _VerseCardActionButtonsWeb extends StatelessWidget {
  final ShareFormat selectedFormat;
  final bool isSharing;
  final bool isSaving;
  final bool isExportingVideo;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onCopyText;
  final VoidCallback? onShareVideo;
  final VoidCallback? onSaveVideo;
  final String? statusMessage;
  final bool isSuccessStatus;

  const _VerseCardActionButtonsWeb({
    required this.selectedFormat,
    required this.isSharing,
    required this.isSaving,
    this.isExportingVideo = false,
    required this.onShare,
    required this.onSave,
    required this.onCopyText,
    this.onShareVideo,
    this.onSaveVideo,
    this.statusMessage,
    this.isSuccessStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

    final buttonPadding = EdgeInsets.symmetric(
      vertical: isLandscape ? 16.0 : 18.0,
      horizontal: isLandscape ? 16.0 : 20.0,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isLandscape ? 14.0 : 16.0),
    );
    final buttonMinSize = Size(0, isLandscape ? 52.0 : 54.0);
    final iconSize = isLandscape ? 22.0 : 24.0;
    final labelStyle = TextStyle(
      fontSize: isLandscape ? 16.5 : 18.0,
      fontWeight: FontWeight.bold,
    );
    final buttonSpacing = isLandscape ? 14.0 : 16.0;

    Widget buildButtons() {
      switch (selectedFormat) {
        case ShareFormat.video:
          return Row(
            key: const ValueKey('video_action_buttons_web'),
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExportingVideo ? null : onSaveVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.accentGold.withValues(alpha: 0.85),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.9),
                    minimumSize: buttonMinSize,
                    padding: buttonPadding,
                    shape: buttonShape,
                    elevation: 2,
                  ),
                  icon: isExportingVideo
                      ? CupertinoActivityIndicator(
                          radius: isLandscape ? 9.0 : 11.0,
                          color: Colors.white,
                        )
                      : Icon(Icons.download_rounded, size: iconSize),
                  label: Text(
                    l10n.videoStudioDownloadVideo,
                    style: labelStyle,
                  ),
                ),
              ),
            ],
          );
        case ShareFormat.image:
        case ShareFormat.fullPage:
          return Row(
            key: const ValueKey('image_action_buttons_web'),
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (isSharing || isSaving) ? null : onShare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.accentGold.withValues(alpha: 0.85),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.9),
                    minimumSize: buttonMinSize,
                    padding: buttonPadding,
                    shape: buttonShape,
                    elevation: 2,
                  ),
                  icon: isSharing
                      ? CupertinoActivityIndicator(
                          radius: isLandscape ? 9.0 : 11.0,
                          color: Colors.white,
                        )
                      : Icon(Icons.share_rounded, size: iconSize),
                  label: Text(
                    l10n.verseCardShareImage,
                    style: labelStyle,
                  ),
                ),
              ),
              SizedBox(width: buttonSpacing),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (isSaving || isSharing) ? null : onSave,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentGold,
                    disabledForegroundColor:
                        AppColors.accentGold.withValues(alpha: 0.85),
                    side: BorderSide(
                      color: AppColors.accentGold.withValues(
                        alpha: (isSaving || isSharing) ? 0.85 : 1.0,
                      ),
                      width: 1.5,
                    ),
                    minimumSize: buttonMinSize,
                    padding: buttonPadding,
                    shape: buttonShape,
                  ),
                  icon: isSaving
                      ? CupertinoActivityIndicator(
                          radius: isLandscape ? 9.0 : 11.0,
                          color: AppColors.accentGold,
                        )
                      : Icon(Icons.download_rounded, size: iconSize),
                  label: Text(
                    l10n.verseCardSaveImage,
                    style: labelStyle,
                  ),
                ),
              ),
            ],
          );
        case ShareFormat.text:
          return SizedBox(
            key: const ValueKey('text_action_buttons_web'),
            width: MediaQuery.sizeOf(context).width,
            child: ElevatedButton.icon(
              onPressed: onCopyText,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.white,
                minimumSize: buttonMinSize,
                padding: buttonPadding,
                shape: buttonShape,
                elevation: 2,
              ),
              icon: Icon(Icons.copy_rounded, size: iconSize),
              label: Text(
                l10n.verseCardCopyText,
                style: labelStyle,
              ),
            ),
          );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: statusMessage == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(statusMessage),
                  margin: const EdgeInsets.only(bottom: 14.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSuccessStatus
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSuccessStatus
                          ? AppColors.accentGold.withValues(alpha: 0.5)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSuccessStatus
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 20.sp,
                        color: isSuccessStatus
                            ? AppColors.accentGold
                            : Colors.red,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          statusMessage!,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: isSuccessStatus
                                ? AppColors.textPrimary
                                : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: buildButtons(),
        ),
      ],
    );
  }
}

class _VideoPreviewViewportWeb extends StatelessWidget {
  final VideoStudioState state;
  final bool isLandscape;
  final VoidCallback onTogglePlay;
  final ValueChanged<int>? onVerseIndexChanged;
  final VoidCallback? onOpenFullscreen;

  const _VideoPreviewViewportWeb({
    required this.state,
    this.isLandscape = false,
    required this.onTogglePlay,
    this.onVerseIndexChanged,
    this.onOpenFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = state.config;
    final verse = state.currentVerse;
    final totalVerses = state.verses.length;
    final currentIndex = state.currentVerseIndex;

    final pageNumber = QuranMetadata.getPageNumberForAyah(
      config.surahNumber,
      verse?.verseNumber ?? config.startAyah,
    );

    final double previewHeight;
    switch (config.aspectRatio) {
      case VideoAspectRatio.portrait9x16:
        previewHeight = isLandscape ? 440.0 : 380.h;
        break;
      case VideoAspectRatio.square1x1:
        previewHeight = isLandscape ? 360.0 : 290.h;
        break;
      case VideoAspectRatio.landscape16x9:
        previewHeight = isLandscape ? 260.0 : 200.h;
        break;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Real Video Preview Card
          Padding(
            padding: EdgeInsets.only(
              top: isLandscape ? 4.0 : 8.h,
              bottom: isLandscape ? 6.0 : 6.h,
              left: isLandscape ? 8.0 : 16.w,
              right: isLandscape ? 8.0 : 16.w,
            ),
            child: RepaintBoundary(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                height: previewHeight,
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: config.aspectRatio.ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isLandscape ? 12.0 : 16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 20,
                          spreadRadius: -1,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isLandscape ? 12.0 : 16.r),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 0. Base Theme Layer (Always keeps the active luxury card theme visible underneath)
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  key: ValueKey('preview_base_bg_${verse?.verseNumber}_${config.themePreset.id}_${config.aspectRatio.name}'),
                                  painter: VideoStaticFramePainter(
                                    config: config.copyWith(backgroundType: VideoBackgroundType.gradient),
                                    verse: verse,
                                    includeBackground: true,
                                  ),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                            if (config.backgroundType == VideoBackgroundType.customVideo &&
                                config.customVideoPath != null &&
                                config.customVideoPath!.isNotEmpty)
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: VideoBackgroundPlayerView(
                                    videoPath: config.customVideoPath!,
                                    isPlaying: state.isPlaying,
                                    dimming: config.backgroundDimming,
                                    resetSignal: state.playbackResetTrigger,
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: VideoStaticFramePainter(
                                    config: config,
                                    verse: verse,
                                    includeBackground: config.backgroundType != VideoBackgroundType.customVideo,
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: StreamBuilder<Duration>(
                                  stream: context.read<VideoStudioBloc>().playbackPositionStream,
                                  initialData: context.read<VideoStudioBloc>().currentVersePosition,
                                  builder: (context, snapshot) {
                                    final position = snapshot.data ?? context.read<VideoStudioBloc>().currentVersePosition;

                                    return CustomPaint(
                                      painter: VideoDynamicContentPainter(
                                        verse: verse,
                                        config: config,
                                        pageNumber: pageNumber,
                                        tafsirText: verse?.tafsir,
                                        translationText: verse?.translation,
                                        playbackPositionMs: position.inMilliseconds,
                                        wordTimings: state.currentVerseWordTimings,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: isLandscape ? 8.0 : 6.h),

          // 2. Bottom Playback & Scrubber Controls Bar (Matching Fullscreen Modal with light luxury theme)
          Padding(
            padding: EdgeInsets.only(
              left: isLandscape ? 8.0 : 16.w,
              right: isLandscape ? 8.0 : 16.w,
              top: isLandscape ? 6.0 : 4.h,
              bottom: isLandscape ? 6.0 : 6.h,
            ),
            child: RepaintBoundary(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 12.0 : 14.w,
                  vertical: isLandscape ? 6.0 : 8.h,
                ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(isLandscape ? 14.0 : 20.r),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Real-time Video Playback Timeline Scrubber
                  if (state.totalVideoDuration > Duration.zero)
                    StreamBuilder<Duration>(
                      stream: context.read<VideoStudioBloc>().playbackPositionStream,
                      initialData: context.read<VideoStudioBloc>().currentVersePosition,
                      builder: (context, snapshot) {
                        final pos = snapshot.data ?? context.read<VideoStudioBloc>().currentVersePosition;
                        final cumulativePos = state.calculateCumulativePosition(state.currentVerseIndex, pos);
                        final posStr = VideoStudioState.formatDurationToMinutesSeconds(cumulativePos);
                        final totalStr = state.formattedTotalDuration ?? '0:00';
                        final totalMs = state.totalVideoDuration.inMilliseconds.toDouble();
                        final currentMs = cumulativePos.inMilliseconds.toDouble().clamp(0.0, totalMs > 0 ? totalMs : 0.0);

                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                          child: Row(
                            children: [
                              SizedBox(
                                width: isLandscape ? 28.0 : 32.w,
                                child: Text(
                                  posStr,
                                  style: TextStyle(
                                    fontSize: isLandscape ? 9.5 : 10.5.sp,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: isLandscape ? 2.5 : 3.h,
                                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: isLandscape ? 4.0 : 5.r),
                                    overlayShape: RoundSliderOverlayShape(overlayRadius: isLandscape ? 8.0 : 10.r),
                                    activeTrackColor: AppColors.accentGold,
                                    inactiveTrackColor: AppColors.accentGold.withValues(alpha: 0.18),
                                    thumbColor: AppColors.accentGold,
                                  ),
                                  child: Slider(
                                    value: currentMs,
                                    min: 0.0,
                                    max: totalMs > 0 ? totalMs : 1.0,
                                    onChanged: (val) {
                                      context.read<VideoStudioBloc>().add(
                                            VideoStudioSeekRequested(
                                              Duration(milliseconds: val.round()),
                                            ),
                                          );
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: isLandscape ? 28.0 : 32.w,
                                child: Text(
                                  totalStr,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: isLandscape ? 9.5 : 10.5.sp,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // Verse indicator / step text
                  if (totalVerses > 0)
                    Padding(
                      padding: EdgeInsets.only(bottom: isLandscape ? 2.0 : 4.h),
                      child: Text(
                        config.startAyah == config.endAyah
                            ? l10n.videoStudioAyahOfSurah(
                                config.startAyah,
                                config.startAyah,
                                QuranMetadata.getSurahNameByLang(
                                  Localizations.localeOf(context).languageCode == 'en',
                                  config.surahNumber,
                                ),
                              )
                            : l10n.videoStudioAyahOfSurah(
                                verse?.verseNumber ?? (config.startAyah + currentIndex),
                                config.endAyah,
                                QuranMetadata.getSurahNameByLang(
                                  Localizations.localeOf(context).languageCode == 'en',
                                  config.surahNumber,
                                ),
                              ),
                        style: TextStyle(
                          fontSize: isLandscape ? 9.5 : 10.5.sp,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Playback Controls Row (Reset on Start, Prev/Play/Next in Center, Fullscreen on End)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Reset / Replay Button (Start edge)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          onPressed: () {
                            context
                                .read<VideoStudioBloc>()
                                .add(const VideoStudioPlaybackReset());
                          },
                          icon: const Icon(Icons.replay_rounded),
                          iconSize: isLandscape ? 18.0 : 20.sp,
                          color: AppColors.accentGold,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: l10n.videoStudioReplayFromStart,
                        ),
                      ),

                      // 2. Center Controls in LTR
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: currentIndex > 0 && onVerseIndexChanged != null
                                  ? () => onVerseIndexChanged!(currentIndex - 1)
                                  : null,
                              icon: const Icon(Icons.skip_previous_rounded),
                              iconSize: isLandscape ? 19.0 : 22.sp,
                              color: AppColors.accentGold,
                              disabledColor: AppColors.textSecondary.withValues(alpha: 0.3),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            SizedBox(width: isLandscape ? 10.0 : 14.w),
                            InkWell(
                              onTap: onTogglePlay,
                              borderRadius: BorderRadius.circular(isLandscape ? 16.0 : 22.r),
                              child: Container(
                                width: isLandscape ? 36.0 : 44.r,
                                height: isLandscape ? 36.0 : 44.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accentGold,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentGold.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: state.isPreparingAudio
                                    ? Center(
                                        child: SizedBox(
                                          width: isLandscape ? 16.0 : 20.r,
                                          height: isLandscape ? 16.0 : 20.r,
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        state.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: isLandscape ? 22.0 : 26.sp,
                                      ),
                              ),
                            ),
                            SizedBox(width: isLandscape ? 10.0 : 14.w),
                            IconButton(
                              onPressed: currentIndex < totalVerses - 1 && onVerseIndexChanged != null
                                  ? () => onVerseIndexChanged!(currentIndex + 1)
                                  : null,
                              icon: const Icon(Icons.skip_next_rounded),
                              iconSize: isLandscape ? 19.0 : 22.sp,
                              color: AppColors.accentGold,
                              disabledColor: AppColors.textSecondary.withValues(alpha: 0.3),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                      // 3. Fullscreen Button (End edge)
                      if (onOpenFullscreen != null)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: IconButton(
                            onPressed: onOpenFullscreen,
                            icon: const Icon(Icons.fullscreen_rounded),
                            iconSize: isLandscape ? 19.0 : 22.sp,
                            color: AppColors.accentGold,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: l10n.videoStudioFullscreenPreview,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}

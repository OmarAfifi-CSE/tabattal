import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/widgets/mixed_direction_text.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/verse_model.dart';
import '../../../bloc/quran/quran_bloc.dart';
import '../../../bloc/quran/quran_event.dart';
import '../../../bloc/quran/quran_state.dart';
import 'audio_settings_sheet_web.dart';
import '../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../bloc/bookmark/bookmark_event.dart';
import '../../../bloc/bookmark/bookmark_state.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../../bloc/audio/audio_event.dart';
import '../../../bloc/hifz/hifz_bloc.dart';
import '../../../bloc/hifz/hifz_event.dart';
import '../../../bloc/hifz/hifz_state.dart';
import '../tablet/verse_card_generator_sheet_tablet.dart';
import '../tafsir_selector_menu.dart';
import '../tablet/word_meanings_sheet_tablet.dart';
import '../overlay_position_delegate.dart';

class VerseActionMenuWeb extends StatefulWidget {
  final void Function({bool keepHighlight}) onDismiss;
  final VoidCallback? onClearHighlight;
  final Offset position;
  final Rect? verseRect;
  final VerseModel verse;
  final GlobalKey? pageRepaintKey;
  final int? pageNumber;

  const VerseActionMenuWeb({
    super.key,
    required this.onDismiss,
    this.onClearHighlight,
    required this.position,
    this.verseRect,
    required this.verse,
    this.pageRepaintKey,
    this.pageNumber,
  });

  @override
  State<VerseActionMenuWeb> createState() => _VerseActionMenuWebState();
}

class _VerseActionMenuWebState extends State<VerseActionMenuWeb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isClosing = false;
  final Map<int, double> _tafsirProgress = {16: 1.0};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _checkDownloadedTafsirs();
    _controller.forward();
  }

  Future<void> _checkDownloadedTafsirs() async {
    if (!mounted) return;
    final repo = context.read<QuranBloc>().repository;
    final toCheck = [
      14,
      91,
      15,
      90,
      93,
      94,
      169,
      168,
      817,
    ]; // Add all non-bundled tafsirs
    final Map<int, double> newProgress = {};
    for (int id in toCheck) {
      final progressResult = await repo.getTafsirDownloadProgress(id);
      progressResult.fold((f) => null, (progress) {
        if (progress > 0.0) {
          newProgress[id] = progress;
        }
      });
    }
    if (newProgress.isNotEmpty && mounted) {
      setState(() {
        _tafsirProgress.addAll(newProgress);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMenuItem(
    IconData icon,
    String text,
    VoidCallback onTap, {
    Color? iconColor,
    bool closeMenu = true,
  }) {
    return _VerseActionMenuItemWeb(
      icon: icon,
      text: text,
      iconColor: iconColor,
      onTap: () {
        if (_isClosing) return;
        if (closeMenu) {
          widget.onDismiss();
        }
        onTap();
      },
    );
  }

  void _close({bool keepHighlight = false}) {
    if (_isClosing) return;
    _isClosing = true;
    _controller.reverse().then((_) {
      _isClosing = false;
      widget.onDismiss(keepHighlight: keepHighlight);
    });
  }

  String _stripHtml(String htmlString) {
    return ArabicTextUtils.cleanTafsirOrHtml(htmlString);
  }

  String _getTafsirName(BuildContext context, int id) {
    final l10n = AppLocalizations.of(context)!;
    switch (id) {
      // Arabic tafsirs
      case 16:
        return l10n.tafsirAlMuyassar;
      case 14:
        return l10n.tafsirIbnKathir;
      case 91:
        return l10n.tafsirAlSaadi;
      case 15:
        return l10n.tafsirAlTabari;
      case 90:
        return l10n.tafsirAlQurtubi;
      case 93:
        return l10n.tafsirAlWaseet;
      case 94:
        return l10n.tafsirAlBaghawi;
      // English tafsirs
      case 169:
        return l10n.tafsirEnIbnKathir;
      case 168:
        return l10n.tafsirEnMaarif;
      case 817:
        return l10n.tafsirEnTazkirul;
      default:
        return l10n.tafsirAlMuyassar;
    }
  }

  void _showOverlayContent(
    BuildContext context,
    String initialTitle,
    QuranState state,
    VoidCallback onRetry,
  ) {
    final quranBloc = context.read<QuranBloc>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background, // Soft cream background
      constraints: null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true, // Allow it to expand nicely
      builder: (bottomSheetContext) {
        return BlocProvider.value(
          value: quranBloc,
          child: StatefulBuilder(
            builder: (context, setState) {
              final l10n = AppLocalizations.of(context)!;
              final isEn = Localizations.localeOf(context).languageCode == 'en';
              return Directionality(
                textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.sizeOf(context).height *
                        0.7, // Max 70% of screen
                  ),
                  padding: EdgeInsets.fromLTRB(20.0, 12.0, 20.0, math.max(20.0, MediaQuery.paddingOf(context).bottom)),
                child: BlocConsumer<QuranBloc, QuranState>(
                  listener: (context, state) {
                    if (state is TafsirDownloaded) {
                      setState(() {
                        _tafsirProgress[state.resourceId] = 1.0;
                      });
                      quranBloc.add(
                        FetchTafsir(
                          widget.verse.verseKey,
                          resourceId: state.resourceId,
                          languageCode: Localizations.localeOf(
                            context,
                          ).languageCode,
                        ),
                      );
                    } else if (state is TafsirDownloading) {
                      setState(() {
                        _tafsirProgress[state.resourceId] = state.progress;
                      });
                    } else if (state is TafsirLoaded) {
                      setState(() {
                        _tafsirProgress[state.tafsir.tafsirId] =
                            state.downloadProgress;
                      });
                    }
                  },
                  builder: (context, currentState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Gold Drag Handle
                        Center(
                          child: Container(
                            width: 48,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (currentState is TafsirLoaded ||
                            currentState is TafsirDownloading ||
                            currentState is TafsirDownloadError ||
                            currentState is TafsirPartialDownloadError ||
                            (currentState is QuranOverlayLoading &&
                                initialTitle.contains(
                                  AppLocalizations.of(context)!.menuTafsir,
                                )))
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Text(
                                  AppLocalizations.of(context)!.menuTafsir,
                                  style: AppTextStyles.headerText.copyWith(
                                    color: AppColors.accentGold,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Builder(
                                  builder: (context) {
                                    final langCode = Localizations.localeOf(
                                      context,
                                    ).languageCode;
                                    int displayResourceId = langCode == 'en'
                                        ? 169
                                        : 16;
                                    if (currentState is TafsirLoaded) {
                                      displayResourceId =
                                          currentState.tafsir.tafsirId;
                                    } else if (currentState
                                        is TafsirDownloading) {
                                      displayResourceId =
                                          currentState.resourceId;
                                    } else if (currentState
                                        is TafsirDownloaded) {
                                      displayResourceId =
                                          currentState.resourceId;
                                    } else if (currentState
                                        is TafsirDownloadError) {
                                      displayResourceId =
                                          currentState.resourceId;
                                    } else if (currentState
                                        is TafsirPartialDownloadError) {
                                      displayResourceId =
                                          currentState.resourceId;
                                    }
                                    return TafsirSelectorMenu(
                                      selectedId: displayResourceId,
                                      options: TafsirOption.getLocalizedOptions(
                                        context,
                                        downloadedIds: const {},
                                        progressMap: _tafsirProgress,
                                        activeDownloadingId:
                                            currentState is TafsirDownloading
                                                ? currentState.resourceId
                                                : null,
                                        activeDownloadProgress:
                                            currentState is TafsirDownloading
                                                ? currentState.progress
                                                : null,
                                      ),
                                      onSelected: (int newValue) {
                                        quranBloc.add(
                                          FetchTafsir(
                                            widget.verse.verseKey,
                                            resourceId: newValue,
                                            languageCode:
                                                Localizations.localeOf(
                                                  context,
                                                ).languageCode,
                                          ),
                                        );
                                      },
                                      openUpwards: true,
                                      menuWidth:
                                          Localizations.localeOf(
                                                context,
                                              ).languageCode ==
                                              'en'
                                          ? 180
                                          : 145,
                                      itemHeight: 38,
                                      itemFontSize: 14,
                                      trigger: Container(
                                        height: 40,
                                        width:
                                            Localizations.localeOf(
                                                  context,
                                                ).languageCode ==
                                                'en'
                                            ? 130
                                            : 100,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: AppColors.accentGold
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: AppColors.accentGold,
                                              size: 20,
                                            ),
                                            Expanded(
                                              child: Text(
                                                _getTafsirName(
                                                  context,
                                                  displayResourceId,
                                                ),
                                                textAlign: TextAlign.center,
                                                style: AppTextStyles
                                                    .menuItemText
                                                    .copyWith(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.accentGold,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            initialTitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headerText.copyWith(
                              color: AppColors.accentGold,
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (currentState is QuranOverlayLoading)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: CupertinoActivityIndicator(
                                color: AppColors.accentGold,
                                radius: 14,
                              ),
                            ),
                          )
                        else if (currentState is TafsirDownloading)
                          Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0.0,
                                end: currentState.progress,
                              ),
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                final l10n = AppLocalizations.of(context)!;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CupertinoActivityIndicator(
                                      radius: 10,
                                      color: AppColors.bronzeIcon,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      l10n.downloadingTafsir(
                                        (value * 100).toStringAsFixed(1) ==
                                                '0.0'
                                            ? 0
                                            : (value * 100).toInt(),
                                      ),
                                      style: AppTextStyles.menuItemText
                                          .copyWith(
                                            fontSize: 14,
                                            color: AppColors.accentGold,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        else if (currentState is TafsirDownloadError)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    currentState.message,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () {
                                      quranBloc.add(
                                        DownloadTafsir(currentState.resourceId),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accentGold,
                                      foregroundColor: AppColors.background,
                                    ),
                                    child: Text(l10n.retry),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (currentState is TafsirPartialDownloadError)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24.0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.downloading_rounded,
                                    color: AppColors.accentGold.withValues(
                                      alpha: 0.8,
                                    ),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.tafsirNotAvailableLocally,
                                    style: AppTextStyles.menuItemText.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.tafsirPartialDownloadHint(
                                      ((_tafsirProgress[currentState
                                                      .resourceId] ??
                                                  0.0) *
                                              100)
                                          .toInt(),
                                    ),
                                    style: AppTextStyles.menuItemText.copyWith(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      quranBloc.add(
                                        DownloadTafsir(currentState.resourceId),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accentGold,
                                      foregroundColor: AppColors.background,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: Text(
                                      l10n.continueDownload,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (currentState is TafsirLoaded)
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (currentState.isDownloading)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 16.0,
                                    ),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: 0.0,
                                        end: currentState.downloadProgress,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      curve: Curves.easeOut,
                                      builder: (context, value, child) {
                                        return Row(
                                          textDirection: isEn
                                              ? TextDirection.ltr
                                              : TextDirection.rtl,
                                          children: [
                                            CupertinoActivityIndicator(
                                              radius: 9,
                                              color: AppColors.accentGold,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.downloadingTafsirBackground,
                                              style: AppTextStyles.menuItemText
                                                  .copyWith(
                                                    fontSize: 12,
                                                    color: AppColors.accentGold,
                                                  ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${(value * 100).toStringAsFixed(1)}%',
                                              style: AppTextStyles.menuItemText
                                                  .copyWith(
                                                    fontSize: 12,
                                                    color: AppColors.accentGold,
                                                  ),
                                              textDirection: TextDirection.ltr,
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                 Flexible(
                                   child: SingleChildScrollView(
                                     physics: const BouncingScrollPhysics(),
                                     child: Column(
                                       crossAxisAlignment:
                                           CrossAxisAlignment.stretch,
                                       children: [
                                         if (currentState
                                                 .tafsir
                                                 .groupVerseRange !=
                                             null) ...[
                                           Align(
                                             alignment:
                                                 Localizations.localeOf(
                                                           context,
                                                         ).languageCode ==
                                                         'ar'
                                                     ? Alignment.centerRight
                                                     : Alignment.centerLeft,
                                             child: Container(
                                               margin: const EdgeInsets.only(
                                                 bottom: 12,
                                               ),
                                               padding:
                                                   const EdgeInsets.symmetric(
                                                     horizontal: 10,
                                                     vertical: 5,
                                                   ),
                                               decoration: BoxDecoration(
                                                 color: AppColors.accentGold
                                                     .withValues(alpha: 0.12),
                                                 borderRadius:
                                                     BorderRadius.circular(20),
                                                 border: Border.all(
                                                   color: AppColors.accentGold
                                                       .withValues(alpha: 0.3),
                                                   width: 1,
                                                 ),
                                               ),
                                               child: Row(
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   Icon(
                                                     currentState
                                                             .tafsir
                                                             .isGroupContinuation
                                                         ? Icons.link_rounded
                                                         : Icons
                                                             .collections_bookmark_rounded,
                                                     size: 14,
                                                     color:
                                                         AppColors.accentGold,
                                                   ),
                                                   const SizedBox(width: 6),
                                                   Text(
                                                     currentState
                                                             .tafsir
                                                             .isGroupContinuation
                                                         ? (Localizations.localeOf(
                                                                   context,
                                                                 ).languageCode ==
                                                                 'ar'
                                                             ? 'تابع تفسير الآيات (${ArabicTextUtils.convertEnglishToArabicDigits(currentState.tafsir.groupVerseRange!)})'
                                                             : 'Continuation of Tafsir for Verses (${currentState.tafsir.groupVerseRange})')
                                                         : (Localizations.localeOf(
                                                                   context,
                                                                 ).languageCode ==
                                                                 'ar'
                                                             ? 'تفسير الآيات (${ArabicTextUtils.convertEnglishToArabicDigits(currentState.tafsir.groupVerseRange!)})'
                                                             : 'Tafsir of Verses (${currentState.tafsir.groupVerseRange})'),
                                                     style: TextStyle(
                                                       fontSize: 12,
                                                       fontWeight:
                                                           FontWeight.bold,
                                                       color:
                                                           AppColors.accentGold,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                           ),
                                         ],
                                         MixedDirectionText(
                                           text: _stripHtml(
                                             currentState.tafsir.text,
                                           ),
                                           style: AppTextStyles.menuItemText
                                               .copyWith(
                                                 height: 1.8,
                                                 color: AppColors.textPrimary,
                                               ),
                                         ),
                                       ],
                                     ),
                                   ),
                                 ),
                              ],
                            ),
                          )
                        else if (currentState is TranslationLoaded)
                          Builder(
                            builder: (context) {
                              final strippedText = _stripHtml(
                                currentState.translation.text,
                              );
                              return Flexible(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: SizedBox(
                                    width: MediaQuery.sizeOf(context).width,
                                    child: MixedDirectionText(
                                      text: strippedText,
                                      style: AppTextStyles.menuItemText
                                          .copyWith(
                                            height: 1.8,
                                            color: AppColors.textPrimary,
                                          ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        else if (currentState is QuranOverlayError)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  currentState.message,
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                    ); // Close sheet to retry safely
                                    onRetry();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentGold,
                                    foregroundColor: AppColors.background,
                                  ),
                                  child: Text(l10n.retry),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
          ),
        );
      },
    ).then((_) {
      if (widget.onClearHighlight != null) {
        widget.onClearHighlight!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const menuSize = Size(240, 280);

    return Stack(
      children: [
        GestureDetector(
          onTap: _close,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
          ),
        ),
        CustomSingleChildLayout(
          delegate: OverlayPositionDelegate(
            tapPosition: widget.position,
            verseRect: widget.verseRect,
            menuSize: menuSize,
            topPadding: MediaQuery.paddingOf(context).top,
            bottomPadding: MediaQuery.paddingOf(context).bottom,
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.topRight,
              child: Material(
              borderRadius: BorderRadius.circular(16),
              color: Colors.transparent,
              child: Container(
                width: 250,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.verseMarkerGold,
                    width: 1.5,
                  ),
                ),
                child: Directionality(
                  textDirection:
                      Localizations.localeOf(context).languageCode == 'ar'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem(
                        Icons.menu_book_outlined,
                        l10n.menuTafsir,
                        () {
                          final qBloc = context.read<QuranBloc>();
                          final langCode = Localizations.localeOf(
                            context,
                          ).languageCode;
                          _showOverlayContent(
                            context,
                            l10n.menuTafsirTitle,
                            qBloc.state,
                            () {
                              qBloc.add(
                                FetchTafsir(
                                  widget.verse.verseKey,
                                  languageCode: langCode,
                                ),
                              );
                            },
                          );
                          qBloc.add(
                            FetchTafsir(
                              widget.verse.verseKey,
                              languageCode: langCode,
                            ),
                          );
                          _close(keepHighlight: true);
                        },
                        closeMenu: false,
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      if (Localizations.localeOf(context).languageCode == 'ar')
                        _buildMenuItem(
                          Icons.translate_rounded,
                          l10n.menuWordMeanings,
                          () {
                            _close(keepHighlight: true);
                            WordMeaningsSheetTablet.show(
                              context,
                              verse: widget.verse,
                            ).then((_) {
                              widget.onClearHighlight?.call();
                            });
                          },
                          closeMenu: false,
                        )
                      else
                        _buildMenuItem(
                          Icons.g_translate_outlined,
                          l10n.menuTranslation,
                          () {
                            final qBloc = context.read<QuranBloc>();
                            _showOverlayContent(
                              context,
                              l10n.menuTranslation,
                              qBloc.state,
                              () {
                                qBloc.add(
                                  FetchTranslation(widget.verse.verseKey),
                                );
                              },
                            );
                            qBloc.add(FetchTranslation(widget.verse.verseKey));
                            _close(keepHighlight: true);
                          },
                          closeMenu: false,
                        ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      BlocBuilder<AudioBloc, AudioState>(
                        builder: (context, audioState) {
                          final isAudioActive =
                              audioState is! AudioIdle &&
                              audioState is! AudioError;
                          return _buildMenuItem(
                            Icons.play_circle_outline,
                            isAudioActive
                                ? l10n.menuGoToVerse
                                : l10n.menuListen,
                            () {
                              if (isAudioActive) {
                                context.read<AudioBloc>().add(
                                  PlayVerse('', widget.verse.id),
                                );
                              } else {
                                showAudioSettingsSheetWeb(
                                  context,
                                  verseId: widget.verse.id,
                                );
                              }
                            },
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      BlocBuilder<HifzBloc, HifzState>(
                        builder: (context, hifzState) {
                          final isHifzActive = hifzState.isHifzModeActive;
                          return _buildMenuItem(
                            isHifzActive
                                ? Icons.visibility_off_outlined
                                : Icons.school_outlined,
                            isHifzActive
                                ? l10n.hifzDisableMode
                                : l10n.hifzEnableMode,
                            () {
                              context.read<HifzBloc>().add(
                                const ToggleHifzMode(),
                              );
                            },
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      _buildMenuItem(
                        Icons.share_outlined,
                        l10n.menuShareCard,
                        () {
                          final qState = context.read<QuranBloc>().state;
                          String? tafsirText;
                          String? translationText;
                          if (qState is TafsirLoaded) {
                            tafsirText = qState.tafsir.text;
                          } else if (qState is TranslationLoaded) {
                            translationText = qState.translation.text;
                          }
                          showVerseCardGeneratorModalTablet(
                            context,
                            verse: widget.verse,
                            tafsirText: tafsirText,
                            translationText: translationText,
                            pageRepaintKey: widget.pageRepaintKey,
                            pageNumber: widget.pageNumber,
                            initialFormat: ShareFormat.video,
                            initialVerses: [widget.verse],
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.divider,
                      ),
                      BlocBuilder<BookmarkBloc, BookmarkState>(
                        builder: (context, state) {
                          final isBookmarked = state.isBookmarked(
                            widget.verse.verseKey,
                          );
                          return _buildMenuItem(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            isBookmarked
                                ? l10n.menuBookmarkRemove
                                : l10n.menuBookmarkAdd,
                            () {
                              context.read<BookmarkBloc>().add(
                                ToggleBookmark(widget.verse.verseKey),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
  }
}

class _VerseActionMenuItemWeb extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Color? iconColor;

  const _VerseActionMenuItemWeb({
    required this.icon,
    required this.text,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.bronzeIcon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.menuItemText.copyWith(
                  color: AppColors.inkBrown,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

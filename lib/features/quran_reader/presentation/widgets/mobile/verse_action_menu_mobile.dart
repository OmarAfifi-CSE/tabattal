import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/verse_model.dart';
import '../../../bloc/quran/quran_bloc.dart';
import '../../../bloc/quran/quran_event.dart';
import '../../../bloc/quran/quran_state.dart';
import 'audio_settings_sheet_mobile.dart';
import '../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../bloc/bookmark/bookmark_event.dart';
import '../../../bloc/bookmark/bookmark_state.dart';
import '../../../bloc/audio/audio_bloc.dart';
import '../../../bloc/audio/audio_state.dart';
import '../../../bloc/audio/audio_event.dart';

class OverlayPositionDelegate extends SingleChildLayoutDelegate {
  final Offset tapPosition;
  final Rect? verseRect;
  final Size menuSize;

  OverlayPositionDelegate({required this.tapPosition, this.verseRect, required this.menuSize});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: menuSize.width,
      maxWidth: menuSize.width,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double left = tapPosition.dx;
    // If verseRect is provided, use its bottom boundary, otherwise fallback to tapPosition + 35
    double top = (verseRect != null && verseRect!.height > 0) ? verseRect!.bottom + 10 : tapPosition.dy + 35; 

    if (left + childSize.width > size.width - 16) {
      left = size.width - childSize.width - 16;
    }
    if (top + childSize.height > size.height - 16) {
      // If opening below goes off-screen, try opening ABOVE the verse
      top = (verseRect != null && verseRect!.height > 0) ? verseRect!.top - childSize.height - 10 : tapPosition.dy - childSize.height - 35; 
      if (top < 16) {
        // Extreme edge case: screen too small to fit above or below, clamp to top
        top = 16; 
      }
    }
    
    if (left < 16) left = 16;

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant OverlayPositionDelegate oldDelegate) {
    return tapPosition != oldDelegate.tapPosition;
  }
}

class VerseActionMenuMobile extends StatefulWidget {
  final void Function({bool keepHighlight}) onDismiss;
  final VoidCallback? onClearHighlight;
  final Offset position;
  final Rect? verseRect;
  final VerseModel verse;

  const VerseActionMenuMobile({
    super.key,
    required this.onDismiss,
    this.onClearHighlight,
    required this.position,
    this.verseRect,
    required this.verse,
  });

  @override
  State<VerseActionMenuMobile> createState() => _VerseActionMenuMobileState();
}

class _VerseActionMenuMobileState extends State<VerseActionMenuMobile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isAnimating = false;
  final Map<int, double> _tafsirProgress = {16: 1.0};

  // Helper to detect if text is primarily RTL (e.g., Arabic, Urdu, Persian)
  bool _isRtl(String text) {
    final RegExp arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    final RegExp englishRegex = RegExp(r'[a-zA-Z]');
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (arabicRegex.hasMatch(char)) return true;
      if (englishRegex.hasMatch(char)) return false;
    }
    return true; // Default to RTL
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _checkDownloadedTafsirs();
    _isAnimating = true;
    _controller.forward().then((_) => _isAnimating = false);
  }

  Future<void> _checkDownloadedTafsirs() async {
    if (!mounted) return;
    final repo = context.read<QuranBloc>().repository;
    final toCheck = [14, 91, 15, 90, 93, 94]; // Add all non-bundled tafsirs
    for (int id in toCheck) {
      final progressResult = await repo.getTafsirDownloadProgress(id);
      progressResult.fold(
        (f) => null,
        (progress) {
          if (progress > 0.0 && mounted) {
            setState(() {
              _tafsirProgress[id] = progress;
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap, {Color? iconColor, bool closeMenu = true}) {
    return GestureDetector(
      onTap: () {
        if (_isAnimating) return;
        onTap();
        if (closeMenu) _close();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.bronzeIcon, size: 22.sp),
            SizedBox(width: 12.w),
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

  void _close({bool keepHighlight = false}) {
    if (_isAnimating) return;
    _isAnimating = true;
    _controller.reverse().then((_) {
      _isAnimating = false;
      widget.onDismiss(keepHighlight: keepHighlight);
    });
  }

  String _stripHtml(String htmlString) {
    // Remove superscript footnotes completely: <sup foot_note=123>1</sup>
    String text = htmlString.replaceAll(RegExp(r'<sup[^>]*>.*?<\/sup>', multiLine: true, caseSensitive: false), '');
    // Replace block tags with newlines to prevent words from squishing
    text = text.replaceAll(RegExp(r'</p>|</li>|<br\s*/?>', caseSensitive: false), '\n\n');
    // Remove all other HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false), '');
    // Remove printed page number annotations from digitized texts e.g. < 1-599 > or &lt; 1-599 &gt;
    text = text.replaceAll(RegExp(r'(<|&lt;)\s*\d+-\d+\s*(>|&gt;)', caseSensitive: false), '');
    // Replace HTML entities and preserve poetry spaces
    text = text.replaceAll('&nbsp;', ' ').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');
    text = text.replaceAll('\\"', '"').replaceAll("\\'", "'");
    // Remove invisible unicode characters and fix non-breaking spaces
    text = text.replaceAll('\u200d', '').replaceAll('\u200c', '').replaceAll('\u200f', '').replaceAll('\u200e', '').replaceAll('\xa0', ' ');
    return text.replaceAll(RegExp(r' {3,}'), '  •  ').trim();
  }

  String _getTafsirName(int id) {
    switch (id) {
      case 16: return 'الميسر';
      case 14: return 'ابن كثير';
      case 91: return 'السعدي';
      case 15: return 'الطبري';
      case 90: return 'القرطبي';
      case 93: return 'الوسيط';
      case 94: return 'البغوي';
      default: return 'الميسر';
    }
  }

  void _showOverlayContent(BuildContext context, String initialTitle, QuranState state, VoidCallback onRetry) {
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
              return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7, // Max 70% of screen
              ),
              padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 20.0),
              child: BlocConsumer<QuranBloc, QuranState>(
                listener: (context, state) {
                  if (state is TafsirDownloaded) {
                    setState(() {
                      _tafsirProgress[state.resourceId] = 1.0;
                    });
                  } else if (state is TafsirDownloading) {
                    setState(() {
                      _tafsirProgress[state.resourceId] = state.progress;
                    });
                  } else if (state is TafsirLoaded) {
                    setState(() {
                      _tafsirProgress[state.tafsir.tafsirId] = state.downloadProgress;
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
                      width: 48.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 16.h),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                      if (currentState is TafsirLoaded || 
                          currentState is TafsirDownloading || 
                          currentState is TafsirDownloadError || 
                          currentState is TafsirPartialDownloadError || 
                          (currentState is QuranOverlayLoading && initialTitle.contains('التفسير')))
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                'التفسير',
                                style: AppTextStyles.headerText.copyWith(color: AppColors.accentGold),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Builder(
                                builder: (context) {
                                  int displayResourceId = 16;
                                  if (currentState is TafsirLoaded) {
                                    displayResourceId = currentState.tafsir.tafsirId;
                                  } else if (currentState is TafsirDownloading) {
                                    displayResourceId = currentState.resourceId;
                                  } else if (currentState is TafsirDownloaded) {
                                    displayResourceId = currentState.resourceId;
                                  } else if (currentState is TafsirDownloadError) {
                                    displayResourceId = currentState.resourceId;
                                  } else if (currentState is TafsirPartialDownloadError) {
                                    displayResourceId = currentState.resourceId;
                                  }
                                  return PopupMenuButton<int>(
                                    splashRadius: 0.1,
                                    initialValue: displayResourceId,
                                    position: PopupMenuPosition.under,
                                    color: AppColors.cardCream,
                                    elevation: 3.r,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.1)),
                                    ),
                                    constraints: BoxConstraints(minWidth: 150.w, maxWidth: 200.w),
                                    onSelected: (int newValue) {
                                      quranBloc.add(FetchTafsir(widget.verse.verseKey, resourceId: newValue));
                                    },
                                    itemBuilder: (context) {
                                      final options = [
                                        (16, 'الميسر'),
                                        (14, 'ابن كثير'),
                                        (91, 'السعدي'),
                                        (15, 'الطبري'),
                                        (90, 'القرطبي'),
                                        (93, 'الوسيط'),
                                        (94, 'البغوي'),
                                      ];
                                      return options.map((option) {
                                        final isSelected = option.$1 == displayResourceId;
                                        final isDownloaded = _tafsirProgress[option.$1] == 1.0;
                                        
                                        final progressStr = (_tafsirProgress.containsKey(option.$1) && _tafsirProgress[option.$1]! > 0.0 && _tafsirProgress[option.$1]! < 1.0)
                                            ? ' (${(_tafsirProgress[option.$1]! * 100).toInt()}%)'
                                            : '';
                                        
                                        return PopupMenuItem<int>(
                                          value: option.$1,
                                          height: 36.h,
                                          padding: EdgeInsets.zero,
                                          child: StatefulBuilder(
                                            builder: (context, setPopupState) {
                                              return Directionality(
                                                textDirection: TextDirection.rtl,
                                                child: Container(
                                                  width: double.infinity,
                                                  height: 36.h,
                                                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                                                  alignment: Alignment.centerRight,
                                                  color: isSelected ? AppColors.accentGold.withValues(alpha: 0.1) : Colors.transparent,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${option.$2}$progressStr',
                                                        style: AppTextStyles.menuItemText.copyWith(
                                                          fontSize: 14.sp,
                                                          color: isSelected ? AppColors.accentGold : AppColors.textPrimary,
                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                        ),
                                                      ),
                                                      if (!isDownloaded && currentState is TafsirDownloading && currentState.resourceId == option.$1)
                                                        SizedBox(
                                                          width: 14.w,
                                                          height: 14.w,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            value: currentState.progress == 0.0 ? null : currentState.progress,
                                                            color: AppColors.accentGold,
                                                          ),
                                                        )
                                                      else if (!isDownloaded)
                                                        Icon(Icons.download_rounded, size: 16.sp, color: AppColors.accentGold.withValues(alpha: 0.7))
                                                      else
                                                        const SizedBox.shrink(),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }
                                          ),
                                        );
                                      }).toList();
                                    },
                                      child: Container(
                                        height: 36.h,
                                        width: 100.w,
                                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(16.r),
                                          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                                        ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentGold, size: 20.sp),
                                          Expanded(
                                            child: Text(
                                              _getTafsirName(displayResourceId),
                                              textAlign: TextAlign.right,
                                              style: AppTextStyles.menuItemText.copyWith(
                                                fontSize: 12.sp,
                                                color: AppColors.accentGold,
                                                fontWeight: FontWeight.w700,
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
                          style: AppTextStyles.headerText.copyWith(color: AppColors.accentGold),
                        ),
                      SizedBox(height: 16.h),
                      if (currentState is QuranOverlayLoading)
                        Center(child: Padding(
                          padding: EdgeInsets.all(32.0.r),
                          child: CircularProgressIndicator(color: AppColors.accentGold),
                        ))
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
                                  SizedBox(
                                    width: 24.sp,
                                    height: 24.sp,
                                    child: CircularProgressIndicator(
                                      value: value == 0.0 ? null : value,
                                      color: AppColors.bronzeIcon,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    l10n.downloadingTafsir((value * 100).toStringAsFixed(1) == '0.0' ? 0 : (value * 100).toInt()),
                                    style: AppTextStyles.menuItemText.copyWith(fontSize: 14.sp, color: AppColors.accentGold),
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
                            padding: EdgeInsets.symmetric(vertical: 16.0.h),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, color: Colors.red, size: 40.sp),
                                SizedBox(height: 12.h),
                                Text(currentState.message, style: const TextStyle(color: Colors.red)),
                                SizedBox(height: 12.h),
                                ElevatedButton(
                                  onPressed: () {
                                    quranBloc.add(DownloadTafsir(currentState.resourceId));
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
                            padding: EdgeInsets.symmetric(vertical: 24.0.h),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.downloading_rounded, color: AppColors.accentGold.withValues(alpha: 0.8), size: 48.sp),
                                SizedBox(height: 16.h),
                                Text(
                                  l10n.tafsirNotAvailableLocally,
                                  style: AppTextStyles.menuItemText.copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  l10n.tafsirPartialDownloadHint(((_tafsirProgress[currentState.resourceId] ?? 0.0) * 100).toInt()),
                                  style: AppTextStyles.menuItemText.copyWith(fontSize: 14.sp, color: Colors.grey[700]),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 24.h),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    quranBloc.add(DownloadTafsir(currentState.resourceId));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentGold,
                                    foregroundColor: AppColors.background,
                                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(l10n.continueDownload, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
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
                                  padding: EdgeInsets.only(bottom: 16.0.h),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0.0,
                                      end: currentState.downloadProgress,
                                    ),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOut,
                                    builder: (context, value, child) {
                                      return Row(
                                        textDirection: TextDirection.rtl,
                                        children: [
                                          SizedBox(
                                            width: 20.sp,
                                            height: 20.sp,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.accentGold,
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Text(
                                            l10n.downloadingTafsirBackground,
                                            style: AppTextStyles.menuItemText.copyWith(fontSize: 12.sp, color: AppColors.accentGold),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${(value * 100).toStringAsFixed(1)}%',
                                            style: AppTextStyles.menuItemText.copyWith(fontSize: 12.sp, color: AppColors.accentGold),
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
                                  child: Text(
                                    _stripHtml(currentState.tafsir.text),
                                    style: AppTextStyles.menuItemText.copyWith(
                                      height: 1.8.h, 
                                      color: AppColors.textPrimary, // Dark charcoal
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (currentState is TranslationLoaded)
                        Builder(
                          builder: (context) {
                            final strippedText = _stripHtml(currentState.translation.text);
                            final isRtl = _isRtl(strippedText);
                            return Flexible(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    strippedText,
                                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                                    style: AppTextStyles.menuItemText.copyWith(
                                      height: 1.8.h,
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
                              Icon(Icons.error_outline, color: Colors.red, size: 40.r),
                              SizedBox(height: 12.h),
                              Text(currentState.message, style: const TextStyle(color: Colors.red)),
                              SizedBox(height: 12.h),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close sheet to retry safely
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
                        )
                    ],
                  );
                },
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
    final menuSize = Size(240.w, 280.h);

    return Stack(
      children: [
        GestureDetector(
          onTap: _close,
          child: SizedBox(width: MediaQuery.sizeOf(context).width, height: MediaQuery.sizeOf(context).height),
        ),
        CustomSingleChildLayout(
          delegate: OverlayPositionDelegate(
            tapPosition: widget.position,
            verseRect: widget.verseRect,
            menuSize: menuSize,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  alignment: Alignment.topRight,
                  child: child,
                ),
              );
            },
            child: Material(
              borderRadius: BorderRadius.circular(16.r),
              color: Colors.transparent,
              child: Container(
                width: 250.w,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCream,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: Offset(0, 8.h),
                    ),
                  ],
                  border: Border.all(color: AppColors.verseMarkerGold, width: 1.5.w),
                ),
                child: Directionality(
                  textDirection: Localizations.localeOf(context).languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      _buildMenuItem(Icons.menu_book_outlined, l10n.menuTafsir, () {
                        _showOverlayContent(context, l10n.menuTafsirTitle, context.read<QuranBloc>().state, () {
                          context.read<QuranBloc>().add(FetchTafsir(widget.verse.verseKey));
                        });
                        context.read<QuranBloc>().add(FetchTafsir(widget.verse.verseKey));
                        _close(keepHighlight: true);
                      }, closeMenu: false),
                      Divider(height: 1.h, thickness: 1, color: AppColors.divider),
                      _buildMenuItem(Icons.g_translate_outlined, l10n.menuTranslation, () {
                        _showOverlayContent(context, l10n.menuTranslation, context.read<QuranBloc>().state, () {
                          context.read<QuranBloc>().add(FetchTranslation(widget.verse.verseKey));
                        });
                        context.read<QuranBloc>().add(FetchTranslation(widget.verse.verseKey));
                        _close(keepHighlight: true);
                      }, closeMenu: false),
                      Divider(height: 1.h, thickness: 1, color: AppColors.divider),
                      BlocBuilder<AudioBloc, AudioState>(
                        builder: (context, audioState) {
                          final isAudioActive = audioState is! AudioIdle && audioState is! AudioError;
                          return _buildMenuItem(
                            Icons.play_circle_outline,
                            isAudioActive ? l10n.menuGoToVerse : l10n.menuListen,
                            () {
                              if (isAudioActive) {
                                context.read<AudioBloc>().add(PlayVerse('', widget.verse.id));
                              } else {
                                showAudioSettingsSheetMobile(context, verseId: widget.verse.id);
                              }
                            },
                          );
                        },
                      ),
                      Divider(height: 1.h, thickness: 1, color: AppColors.divider),
                      BlocBuilder<BookmarkBloc, BookmarkState>(
                        builder: (context, state) {
                          final isBookmarked = state.isBookmarked(widget.verse.verseKey);
                          return _buildMenuItem(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            isBookmarked ? l10n.menuBookmarkRemove : l10n.menuBookmarkAdd,
                            () {
                              context.read<BookmarkBloc>().add(ToggleBookmark(widget.verse.verseKey));
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
      ],
    );
  }
}



import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/verse_model.dart';
import '../bloc/quran/quran_bloc.dart';
import '../bloc/quran/quran_event.dart';
import '../bloc/quran/quran_state.dart';
import 'audio_settings_sheet.dart';
import '../bloc/bookmark/bookmark_bloc.dart';
import '../bloc/bookmark/bookmark_event.dart';
import '../bloc/bookmark/bookmark_state.dart';
class OverlayPositionDelegate extends SingleChildLayoutDelegate {
  final Offset tapPosition;
  final Rect? verseRect;
  final Size menuSize;

  OverlayPositionDelegate({required this.tapPosition, this.verseRect, required this.menuSize});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.tight(menuSize);
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

class VerseActionMenu extends StatefulWidget {
  final void Function({bool keepHighlight}) onDismiss;
  final VoidCallback? onClearHighlight;
  final Offset position;
  final Rect? verseRect;
  final VerseModel verse;

  const VerseActionMenu({
    super.key,
    required this.onDismiss,
    this.onClearHighlight,
    required this.position,
    this.verseRect,
    required this.verse,
  });

  @override
  State<VerseActionMenu> createState() => _VerseActionMenuState();
}

class _VerseActionMenuState extends State<VerseActionMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isAnimating = false;
  final Map<int, double> _tafsirProgress = {16: 1.0, 14: 1.0, 91: 1.0};

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
    final toCheck = [15, 90, 93, 94]; // Add all non-bundled tafsirs
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
    return InkWell(
      onTap: () {
        if (_isAnimating) return; // Prevent concurrent rapid taps
        onTap();
        if (closeMenu) {
          _close();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? const Color(0xFF8C7355), // Faded brown icon
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.menuItemText.copyWith(
                  color: const Color(0xFF2C2520), // Dark brown text
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
      backgroundColor: const Color(0xFFFBF7F0), // Soft cream background
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true, // Allow it to expand nicely
      builder: (bottomSheetContext) {
        return BlocProvider.value(
          value: quranBloc,
          child: StatefulBuilder(
            builder: (context, setState) {
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
                                    initialValue: displayResourceId,
                                    position: PopupMenuPosition.under,
                                    color: Colors.white,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.1)),
                                    ),
                                    constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
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
                                          height: 36,
                                          padding: EdgeInsets.zero,
                                          child: StatefulBuilder(
                                            builder: (context, setPopupState) {
                                              return Directionality(
                                                textDirection: TextDirection.rtl,
                                                child: Container(
                                                  width: double.infinity,
                                                  height: 36,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                  alignment: Alignment.centerRight,
                                                  color: isSelected ? AppColors.accentGold.withValues(alpha: 0.1) : Colors.transparent,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${option.$2}$progressStr',
                                                        style: AppTextStyles.menuItemText.copyWith(
                                                          fontSize: 14,
                                                          color: isSelected ? AppColors.accentGold : const Color(0xFF2C2520),
                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                        ),
                                                      ),
                                                      if (!isDownloaded && currentState is TafsirDownloading && currentState.resourceId == option.$1)
                                                        SizedBox(
                                                          width: 14,
                                                          height: 14,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            value: currentState.progress == 0.0 ? null : currentState.progress,
                                                            color: AppColors.accentGold,
                                                          ),
                                                        )
                                                      else if (!isDownloaded)
                                                        Icon(Icons.download_rounded, size: 16, color: AppColors.accentGold.withValues(alpha: 0.7))
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
                                      height: 36,
                                      width: 100,
                                      padding: const EdgeInsets.only(left: 10, right: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentGold, size: 20),
                                          Expanded(
                                            child: Text(
                                              _getTafsirName(displayResourceId),
                                              textAlign: TextAlign.right,
                                              style: AppTextStyles.menuItemText.copyWith(
                                                color: AppColors.accentGold,
                                                fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 16),
                      if (currentState is QuranOverlayLoading)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: AppColors.accentGold),
                        ))
                      else if (currentState is TafsirDownloading)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    begin: 0.0,
                                    end: currentState.progress,
                                  ),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          value: value == 0.0 ? null : value,
                                          color: AppColors.accentGold,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'جاري تحميل التفسير... ${(value * 100).toStringAsFixed(1)}%',
                                          style: AppTextStyles.menuItemText.copyWith(fontSize: 14, color: AppColors.accentGold),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                          ),
                        )
                      else if (currentState is TafsirDownloadError)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                                const SizedBox(height: 12),
                                Text(currentState.message, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    quranBloc.add(DownloadTafsir(currentState.resourceId));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentGold,
                                    foregroundColor: AppColors.background,
                                  ),
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (currentState is TafsirPartialDownloadError)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.downloading_rounded, color: AppColors.accentGold.withValues(alpha: 0.8), size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  'تفسير هذه الآية غير متوفر محلياً',
                                  style: AppTextStyles.menuItemText.copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'تم تحميل ${((_tafsirProgress[currentState.resourceId] ?? 0.0) * 100).toInt()}% من التفسير. هل ترغب في استكمال التحميل؟',
                                  style: AppTextStyles.menuItemText.copyWith(fontSize: 14, color: Colors.grey[700]),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    quranBloc.add(DownloadTafsir(currentState.resourceId));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentGold,
                                    foregroundColor: AppColors.background,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('استكمال التحميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                                  padding: const EdgeInsets.only(bottom: 16.0),
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
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.accentGold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'جاري تحميل باقي التفسير في الخلفية...',
                                            style: AppTextStyles.menuItemText.copyWith(fontSize: 12, color: AppColors.accentGold),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${(value * 100).toStringAsFixed(1)}%',
                                            style: AppTextStyles.menuItemText.copyWith(fontSize: 12, color: AppColors.accentGold),
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
                                      height: 1.8, 
                                      color: const Color(0xFF2C2520), // Dark charcoal
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (currentState is TranslationLoaded)
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              _stripHtml(currentState.translation.text),
                              style: AppTextStyles.menuItemText.copyWith(
                                height: 1.8,
                                color: const Color(0xFF2C2520),
                              ),
                            ),
                          ),
                        )
                      else if (currentState is QuranOverlayError)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 12),
                              Text(currentState.message, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close sheet to retry safely
                                  onRetry();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentGold,
                                  foregroundColor: AppColors.background,
                                ),
                                child: const Text('Retry'),
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
    const menuSize = Size(220.0, 280.0);

    return Stack(
      children: [
        GestureDetector(
          onTap: _close,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            width: double.infinity,
            height: double.infinity,
          ),
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
              color: Colors.transparent,
              child: Container(
                width: menuSize.width,
                height: menuSize.height,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF4E8), // Cream beige from design
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFC7B698), // Gold/Brown border
                    width: 1.5,
                  ),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      _buildMenuItem(Icons.menu_book_outlined, 'التفسير', () {
                        _showOverlayContent(context, 'التفسير - الميسر', context.read<QuranBloc>().state, () {
                          context.read<QuranBloc>().add(FetchTafsir(widget.verse.verseKey));
                        });
                        context.read<QuranBloc>().add(FetchTafsir(widget.verse.verseKey));
                        _close(keepHighlight: true);
                      }, closeMenu: false),
                      const Divider(height: 1, thickness: 1, color: AppColors.divider),
                      _buildMenuItem(Icons.g_translate_outlined, 'الترجمة', () {
                        _showOverlayContent(context, 'الترجمة', context.read<QuranBloc>().state, () {
                          context.read<QuranBloc>().add(FetchTranslation(widget.verse.verseKey));
                        });
                        context.read<QuranBloc>().add(FetchTranslation(widget.verse.verseKey));
                        _close(keepHighlight: true);
                      }, closeMenu: false),
                      const Divider(height: 1, thickness: 1, color: AppColors.divider),
                      _buildMenuItem(Icons.play_circle_outline, 'الإستماع للآيات', () {
                        showAudioSettingsSheet(context, verseId: widget.verse.id);
                      }),
                      const Divider(height: 1, thickness: 1, color: AppColors.divider),
                      BlocBuilder<BookmarkBloc, BookmarkState>(
                        builder: (context, state) {
                          final isBookmarked = state.isBookmarked(widget.verse.verseKey);
                          return _buildMenuItem(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            'أضف للمفضلة',
                            () {
                              context.read<BookmarkBloc>().add(ToggleBookmark(widget.verse.verseKey));
                            },
                          );
                        },
                      ),
                      const Divider(height: 1, thickness: 1, color: AppColors.divider),
                      _buildMenuItem(Icons.share_outlined, 'نشر', () {
                        // Share logic
                      }),
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

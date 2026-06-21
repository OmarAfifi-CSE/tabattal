import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/verse_model.dart';
import '../bloc/quran/quran_bloc.dart';
import '../bloc/quran/quran_event.dart';
import '../bloc/quran/quran_state.dart';
import '../bloc/audio/audio_bloc.dart';
import '../bloc/audio/audio_event.dart';
import '../bloc/bookmark/bookmark_bloc.dart';
import '../bloc/bookmark/bookmark_event.dart';
import '../bloc/bookmark/bookmark_state.dart';

class OverlayPositionDelegate extends SingleChildLayoutDelegate {
  final Offset tapPosition;
  final Size menuSize;

  OverlayPositionDelegate({required this.tapPosition, required this.menuSize});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.tight(menuSize);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // 16 is padding from edge
    double left = tapPosition.dx;
    double top = tapPosition.dy;

    if (left + childSize.width > size.width - 16) {
      left = size.width - childSize.width - 16;
    }
    if (top + childSize.height > size.height - 16) {
      // If we clip at the bottom, we try to open it ABOVE the tap position
      top = tapPosition.dy - childSize.height - 24; 
      if (top < 16) {
        top = 16; // Extreme edge case: screen too small, clamp to top
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
  final VoidCallback onDismiss;
  final Offset position;
  final VerseModel verse;

  const VerseActionMenu({
    super.key,
    required this.onDismiss,
    required this.position,
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _isAnimating = true;
    _controller.forward().then((_) => _isAnimating = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap, {Color? iconColor}) {
    return InkWell(
      onTap: () {
        if (_isAnimating) return; // Prevent concurrent rapid taps
        onTap();
        _close();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              text,
              style: AppTextStyles.menuItemText.copyWith(
                color: const Color(0xFF2C2520), // Dark brown text
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              color: iconColor ?? const Color(0xFF8C7355), // Faded brown icon
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _close() {
    if (_isAnimating) return;
    _isAnimating = true;
    _controller.reverse().then((_) {
      _isAnimating = false;
      widget.onDismiss();
    });
  }

  void _showOverlayContent(BuildContext context, String title, QuranState state, VoidCallback onRetry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: AppTextStyles.headerText.copyWith(color: AppColors.accentGold),
              ),
              const SizedBox(height: 16),
              if (state is TafsirLoaded)
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      state.tafsir.text,
                      style: AppTextStyles.menuItemText.copyWith(height: 1.6),
                      textAlign: TextAlign.justify,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                )
              else if (state is TranslationLoaded)
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      state.translation.text,
                      style: AppTextStyles.menuItemText.copyWith(height: 1.6),
                    ),
                  ),
                )
              else if (state is QuranOverlayError)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 12),
                      Text(state.message, style: const TextStyle(color: Colors.red)),
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
              else
                const Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
            ],
          ),
        );
      },
    );
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
                child: BlocListener<QuranBloc, QuranState>(
                  listener: (context, state) {
                    if (state is TafsirLoaded) {
                      _showOverlayContent(context, 'التفسير - ابن كثير', state, () {
                        context.read<QuranBloc>().add(FetchTafsir(widget.verse.verseKey));
                      });
                    } else if (state is TranslationLoaded) {
                      _showOverlayContent(context, 'Translation', state, () {
                        context.read<QuranBloc>().add(FetchTranslation(widget.verse.verseKey));
                      });
                    } else if (state is QuranOverlayError) {
                      _showOverlayContent(context, 'Error', state, () {
                        // determine if it was tafsir or translation based on current request maybe?
                        // For simplicity, we just provide a generic retry mechanism or require reopening menu.
                        // Ideally we pass the last event to retry.
                        context.read<QuranBloc>().add(FetchTafsir(widget.verse.verseKey)); 
                      });
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem(Icons.menu_book_outlined, 'التفسير', () {
                        context.read<QuranBloc>().add(FetchTafsir(widget.verse.verseKey));
                      }),
                      const Divider(height: 1, thickness: 1, color: AppColors.divider),
                      _buildMenuItem(Icons.g_translate_outlined, 'الترجمة', () {
                        context.read<QuranBloc>().add(FetchTranslation(widget.verse.verseKey));
                      }),
                      const Divider(height: 1, thickness: 1, color: AppColors.divider),
                      _buildMenuItem(Icons.play_circle_outline, 'الإستماع للآيات', () {
                        context.read<AudioBloc>().add(PlayVerse(widget.verse.audioUrl, widget.verse.id));
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

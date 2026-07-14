import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../../bloc/bookmark/bookmark_event.dart';
import '../../../../bloc/bookmark/bookmark_state.dart';
import '../../../../../quran_reader/domain/repositories/quran_repository.dart';
import '../../../../../../core/utils/verse_ref.dart';
import '../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../../core/constants/quran_metadata.dart';
class QuranBookmarksViewWeb extends StatelessWidget {
  const QuranBookmarksViewWeb({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final content = Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.bookmarksTitle,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<BookmarkBloc, BookmarkState>(
        builder: (context, state) {
          if (state.bookmarkedVerseKeys.isEmpty) return _buildEmptyState(context);

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.bookmarkedVerseKeys.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final verseKey = state.bookmarkedVerseKeys[index];
              final verseRef = VerseRef.fromKey(verseKey);

              return _BookmarkCard(
                verseKey: verseKey,
                surahName: QuranMetadata.getSurahName(verseRef.surah),
                surahNum: verseRef.surah,
                ayahNum: verseRef.ayah,
                onNavigate: (page) => Navigator.pop(context, {'page': page, 'verseKey': verseKey}),
              );
            },
          );
        },
      ),
    );
    return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: content,
          ),
        ),
      );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 72, color: AppColors.accentGold.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            l10n.noBookmarks,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noBookmarksHint,
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bookmark Card
// ---------------------------------------------------------------------------

class _BookmarkCard extends StatefulWidget {
  final String verseKey;
  final String surahName;
  final int surahNum;
  final int ayahNum;
  final void Function(int page) onNavigate;

  const _BookmarkCard({
    required this.verseKey,
    required this.surahName,
    required this.surahNum,
    required this.ayahNum,
    required this.onNavigate,
  });

  @override
  State<_BookmarkCard> createState() => _BookmarkCardState();
}

class _BookmarkCardState extends State<_BookmarkCard> {
  bool _isLoadingPage = true;
  bool _hasError = false;
  int _surahStartPage = 1;

  @override
  void initState() {
    super.initState();
    _loadVersePage();
  }

  Future<void> _loadVersePage() async {
    final result = await context.read<QuranRepository>().getPageForVerse(widget.verseKey);
    result.fold(
      (failure) {
        if (mounted) setState(() { _isLoadingPage = false; _hasError = true; });
      },
      (page) {
        if (mounted) {
          setState(() {
            _isLoadingPage = false;
            _surahStartPage = page;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: (_isLoadingPage || _hasError) ? null : () => widget.onNavigate(_surahStartPage),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.bookmark_rounded, color: AppColors.accentGold, size: 24),
        ),
        title: Text(
          l10n.surahBookmarkTitle(widget.surahName),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            l10n.verseBookmarkSubtitle(
              widget.ayahNum.toArabicDigits,
              _hasError ? '—' : _surahStartPage.toArabicDigits,
            ),
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary.withValues(alpha: 0.55)),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingPage)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold),
              )
            else
              Icon(
                _hasError ? Icons.error_outline : Icons.arrow_back_ios_rounded,
                size: 16,
                color: _hasError ? Colors.red.withValues(alpha: 0.6) : AppColors.textPrimary.withValues(alpha: 0.3),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.withValues(alpha: 0.65), size: 22),
              onPressed: () => context.read<BookmarkBloc>().add(ToggleBookmark(widget.verseKey)),
            ),
          ],
        ),
      ),
    );
  }
}

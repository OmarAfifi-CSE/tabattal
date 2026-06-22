import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/bookmark/bookmark_bloc.dart';
import '../../bloc/bookmark/bookmark_event.dart';
import '../../bloc/bookmark/bookmark_state.dart';
import '../../../../quran_reader/domain/repositories/quran_repository.dart';
import '../../../../../core/utils/verse_ref.dart';
import '../quran_metadata.dart';

class QuranBookmarksView extends StatelessWidget {
  const QuranBookmarksView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF5EB),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'العلامات المرجعية',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<BookmarkBloc, BookmarkState>(
        builder: (context, state) {
          if (state.bookmarkedVerseKeys.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 72,
                    color: AppColors.accentGold.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد علامات مرجعية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط على أي آية لإضافتها للمفضلة',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.bookmarkedVerseKeys.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final verseKey = state.bookmarkedVerseKeys[index];
              final verseRef = VerseRef.fromKey(verseKey);
              final surahName = QuranMetadata.getSurahName(verseRef.surah);

              return _BookmarkCard(
                verseKey: verseKey,
                surahName: surahName,
                surahNum: verseRef.surah,
                ayahNum: verseRef.ayah,
                onNavigate: (page) => Navigator.pop(
                  context,
                  {'page': page, 'verseKey': verseKey},
                ),
              );
            },
          );
        },
      ),
    );
  }
}

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
  bool _isLoading = true;
  int _surahStartPage = 1;

  @override
  void initState() {
    super.initState();
    _loadSurahPage();
  }

  Future<void> _loadSurahPage() async {
    final repo = context.read<QuranRepository>();
    final indexResult = await repo.getSurahsIndex();
    indexResult.fold(
      (f) {
        if (mounted) setState(() => _isLoading = false);
      },
      (index) {
        final surahData = index.firstWhere(
          (r) => r['surah'] == widget.surahNum,
          orElse: () => <String, dynamic>{'start_page': 1},
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
            _surahStartPage = surahData['start_page'] as int? ?? 1;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: _isLoading
            ? null
            : () => widget.onNavigate(_surahStartPage),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bookmark_rounded, color: AppColors.accentGold, size: 24),
        ),
        title: Text(
          'سورة ${widget.surahName}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'الآية ${widget.ayahNum}  •  صفحة $_surahStartPage',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary.withValues(alpha: 0.55),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold),
              )
            else
              Icon(
                Icons.arrow_back_ios_rounded,
                size: 16,
                color: AppColors.textPrimary.withValues(alpha: 0.3),
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

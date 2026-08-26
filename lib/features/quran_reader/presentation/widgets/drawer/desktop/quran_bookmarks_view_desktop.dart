import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../../../core/utils/verse_ref.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../quran_reader/domain/repositories/quran_repository.dart';
import '../../../../bloc/bookmark/bookmark_bloc.dart';
import '../../../../bloc/bookmark/bookmark_event.dart';
import '../../../../bloc/bookmark/bookmark_state.dart';

class QuranBookmarksViewDesktop extends StatelessWidget {
  const QuranBookmarksViewDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.bookmarksTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24.sp,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 26.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<BookmarkBloc, BookmarkState>(
        builder: (context, state) {
          if (state.bookmarkedVerseKeys.isEmpty) {
            return const _EmptyBookmarksViewDesktop();
          }

          final isLandscape =
              MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

          if (isLandscape) {
            return GridView.builder(
              padding: EdgeInsets.all(16.r),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 16.w,
              ),
              itemCount: state.bookmarkedVerseKeys.length,
              itemBuilder: (context, index) {
                final verseKey = state.bookmarkedVerseKeys[index];
                final verseRef = VerseRef.fromKey(verseKey);

                return _BookmarkCard(
                  verseKey: verseKey,
                  surahName: QuranMetadata.getSurahName(verseRef.surah),
                  surahNum: verseRef.surah,
                  ayahNum: verseRef.ayah,
                  onNavigate: (page) => Navigator.pop(context, {
                    'page': page,
                    'verseKey': verseKey,
                  }),
                );
              },
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16.w,
              16.h,
              16.w,
              16.h + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: state.bookmarkedVerseKeys.length,
            separatorBuilder: (context, index) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              final verseKey = state.bookmarkedVerseKeys[index];
              final verseRef = VerseRef.fromKey(verseKey);

              return _BookmarkCard(
                verseKey: verseKey,
                surahName: QuranMetadata.getSurahName(verseRef.surah),
                surahNum: verseRef.surah,
                ayahNum: verseRef.ayah,
                onNavigate: (page) => Navigator.pop(context, {
                  'page': page,
                  'verseKey': verseKey,
                }),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyBookmarksViewDesktop extends StatelessWidget {
  const _EmptyBookmarksViewDesktop();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 84.sp,
            color: AppColors.accentGold.withValues(alpha: 0.4),
          ),
          SizedBox(height: 16.h),
          Text(
            l10n.noBookmarks,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            l10n.noBookmarksHint,
            style: TextStyle(
              fontSize: 16.5.sp,
              color: AppColors.textPrimary.withValues(alpha: 0.4),
            ),
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

class _BookmarkCardState extends State<_BookmarkCard>
    with AutomaticKeepAliveClientMixin {
  static final Map<String, int> _versePageCache = {};

  bool _isLoadingPage = true;
  bool _hasError = false;
  int _surahStartPage = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (_versePageCache.containsKey(widget.verseKey)) {
      _surahStartPage = _versePageCache[widget.verseKey]!;
      _isLoadingPage = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadVersePage();
        }
      });
    }
  }

  Future<void> _loadVersePage() async {
    final result = await context.read<QuranRepository>().getPageForVerse(
      widget.verseKey,
    );
    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isLoadingPage = false;
            _hasError = true;
          });
        }
      },
      (page) {
        _versePageCache[widget.verseKey] = page;
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
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Material(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(16.r),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
          onTap: (_isLoadingPage || _hasError)
              ? null
              : () => widget.onNavigate(_surahStartPage),
          leading: Container(
            width: 52.r,
            height: 52.r,
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_rounded,
              color: AppColors.accentGold,
              size: 28.sp,
            ),
          ),
          title: Text(
            l10n.surahBookmarkTitle(widget.surahName),
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 3.h),
            child: Text(
              l10n.verseBookmarkSubtitle(
                widget.ayahNum.toArabicDigits,
                _hasError ? '—' : _surahStartPage.toArabicDigits,
              ),
              style: TextStyle(
                fontSize: 16.sp,
                color: AppColors.textPrimary.withValues(alpha: 0.55),
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingPage)
                CupertinoActivityIndicator(
                  radius: 10.r,
                  color: AppColors.accentGold,
                )
              else
                Icon(
                  _hasError ? Icons.error_outline : Icons.arrow_back_ios_rounded,
                  size: 20.sp,
                  color: _hasError
                      ? Colors.red.withValues(alpha: 0.6)
                      : AppColors.textPrimary.withValues(alpha: 0.3),
                ),
              SizedBox(width: 8.w),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.withValues(alpha: 0.65),
                  size: 26.sp,
                ),
                onPressed: () => context.read<BookmarkBloc>().add(
                  ToggleBookmark(widget.verseKey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

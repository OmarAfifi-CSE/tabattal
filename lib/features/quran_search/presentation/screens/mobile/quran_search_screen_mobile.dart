import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/utils/arabic_text_utils.dart';
import '../../../../quran_reader/domain/repositories/quran_repository.dart';
import '../../../data/models/search_verse_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/constants/quran_metadata.dart';
import '../../../../../../core/constants/quran_topics.dart';

class QuranSearchScreenMobile extends StatefulWidget {
  const QuranSearchScreenMobile({super.key});

  @override
  State<QuranSearchScreenMobile> createState() =>
      _QuranSearchScreenMobileState();
}

class _QuranSearchScreenMobileState extends State<QuranSearchScreenMobile> {
  final TextEditingController _searchController = TextEditingController();
  late final QuranRepository _repository;

  Timer? _debounce;
  bool _isLoading = false;
  List<SearchVerseModel> _results = [];
  bool _isNumericSearch = false;

  QuranTopic? _selectedTopic;
  QuranSubTopic? _selectedSubTopic;

  Map<int, int> _surahPageMap = {};
  bool _surahMapLoaded = false;

  static const List<int> _juzStartPages = [
    1,
    22,
    42,
    62,
    82,
    102,
    122,
    142,
    162,
    182,
    202,
    222,
    242,
    262,
    282,
    302,
    322,
    342,
    362,
    382,
    402,
    422,
    442,
    462,
    482,
    502,
    522,
    542,
    562,
    582,
  ];

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _surahPageMap = {
      for (int i = 1; i <= 114; i++) i: QuranMetadata.getStartPageForSurah(i),
    };
    _surahMapLoaded = true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_selectedTopic != null) {
      setState(() {
        _selectedTopic = null;
        _selectedSubTopic = null;
      });
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  void _selectTopic(QuranTopic topic) async {
    setState(() {
      _selectedTopic = topic;
      _selectedSubTopic = null;
      _isLoading = true;
    });

    List<VerseRange> ranges = [];
    if (topic.subTopics != null && topic.subTopics!.isNotEmpty) {
      for (final sub in topic.subTopics!) {
        ranges.addAll(sub.verseRanges);
      }
    } else {
      ranges = topic.verseRanges;
    }

    final res = await _repository.getVersesByRanges(ranges);
    res.fold(
      (f) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _results = [];
          });
        }
      },
      (results) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isNumericSearch = false;
            _results = results;
          });
        }
      },
    );
  }

  void _selectSubTopic(QuranSubTopic? subTopic) async {
    if (_selectedTopic == null) return;
    setState(() {
      _selectedSubTopic = subTopic;
      _isLoading = true;
    });

    List<VerseRange> ranges = [];
    if (subTopic != null) {
      ranges = subTopic.verseRanges;
    } else if (_selectedTopic!.subTopics != null) {
      for (final sub in _selectedTopic!.subTopics!) {
        ranges.addAll(sub.verseRanges);
      }
    } else {
      ranges = _selectedTopic!.verseRanges;
    }

    final res = await _repository.getVersesByRanges(ranges);
    res.fold(
      (f) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _results = [];
          });
        }
      },
      (results) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isNumericSearch = false;
            _results = results;
          });
        }
      },
    );
  }

  void _clearSelectedTopic() {
    setState(() {
      _selectedTopic = null;
      _selectedSubTopic = null;
      _results = [];
    });
    if (_searchController.text.isNotEmpty) {
      _onSearchChanged(_searchController.text);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isNumericSearch = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final normalizedQuery = _normalizeArabicNumbers(query.trim());

    if (int.tryParse(normalizedQuery) != null) {
      setState(() {
        _isNumericSearch = true;
        _results = [];
        _isLoading = false;
      });
      return;
    }

    final searchResult = await _repository.searchQuran(normalizedQuery);
    searchResult.fold(
      (f) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _results = [];
          });
        }
      },
      (results) {
        if (mounted) {
          setState(() {
            _isNumericSearch = false;
            _results = results;
            _isLoading = false;
          });
        }
      },
    );
  }

  void _navigateToPage(int pageNumber, {String? verseKey}) {
    Navigator.pop(context, {'page': pageNumber, 'verseKey': verseKey});
  }

  static final _tashkeelRegex = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u0640]',
  );
  static final _alefRegex = RegExp(r'[اأإآٱى]');
  static final _surahPrefixRegex = RegExp(r'^(سورة|سوره|surah)\s*', caseSensitive: false);
  static final _delimiterRegex = RegExp(r'[,،|]+');
  static final _whitespaceRegex = RegExp(r'\s+');
  static final _nonAlphaNumeric = RegExp(r'[^a-z0-9]');

  static String _normalizeArabicNumbers(String input) {
    const arabicNumbers = '٠١٢٣٤٥٦٧٨٩';
    const englishNumbers = '0123456789';
    String result = input;
    for (int i = 0; i < arabicNumbers.length; i++) {
      result = result.replaceAll(arabicNumbers[i], englishNumbers[i]);
    }
    return result;
  }

  static String _smartNormalize(String text) {
    String c = _normalizeArabicNumbers(text);
    c = c.replaceAll(_tashkeelRegex, '');
    c = c.replaceAll('ـ', '');
    c = c.replaceAll(_alefRegex, '');
    c = c.replaceAll('ة', 'ه');
    c = c.replaceAll('ئ', 'ي');
    c = c.replaceAll('ؤ', 'و');
    return c;
  }

  static final List<({int surahNum, String normArabic, String normEnglish})> _normalizedSurahCache = [
    for (int i = 1; i <= 114; i++)
      (
        surahNum: i,
        normArabic: _smartNormalize(QuranMetadata.getSurahName(i)),
        normEnglish: QuranMetadata.getSurahNameEnglish(i).toLowerCase().replaceAll(_nonAlphaNumeric, ''),
      )
  ];

  List<int> _getMatchingSurahs(String rawQuery) {
    final queryText = rawQuery.trim();
    if (queryText.isEmpty) return [];

    String cleaned = queryText.replaceAll(_surahPrefixRegex, '');
    if (cleaned.isEmpty) return [];

    final normQuery = _smartNormalize(cleaned);
    if (normQuery.isEmpty) return [];

    final exactMatches = <int>[];
    final partialMatches = <int>[];
    final normQueryLower = normQuery.toLowerCase();

    for (final s in _normalizedSurahCache) {
      if (s.normArabic == normQuery || s.normEnglish == normQueryLower) {
        exactMatches.add(s.surahNum);
      } else if (s.normArabic.contains(normQuery) || s.normEnglish.contains(normQueryLower)) {
        partialMatches.add(s.surahNum);
      }
    }

    return [...exactMatches, ...partialMatches];
  }

  List<TextSpan> _getHighlightedUthmani(
    String textClean,
    String textUthmani,
    String query,
  ) {
    if (query.isEmpty) return [TextSpan(text: textUthmani)];

    String cleanedQuery = query.trim().replaceAll(_surahPrefixRegex, '');
    if (cleanedQuery.isEmpty) cleanedQuery = query.trim();

    final rawTerms = cleanedQuery.split(_delimiterRegex);
    final queryWords = <String>[];
    for (final term in rawTerms) {
      for (final w in term.trim().split(_whitespaceRegex)) {
        final norm = _smartNormalize(w);
        if (norm.isNotEmpty) queryWords.add(norm);
      }
    }
    if (queryWords.isEmpty) return [TextSpan(text: textUthmani)];

    final cleanWords = textClean.split(' ');
    final uthmaniWords = textUthmani.split(' ');

    final spans = <TextSpan>[];

    for (int i = 0; i < uthmaniWords.length; i++) {
      final cleanW = i < cleanWords.length ? _smartNormalize(cleanWords[i]) : '';
      bool isMatch = false;

      for (final qw in queryWords) {
        if (cleanW.contains(qw)) {
          isMatch = true;
          break;
        }
      }

      final wordText = i < uthmaniWords.length - 1 ? '${uthmaniWords[i]} ' : uthmaniWords[i];

      if (isMatch) {
        spans.add(
          TextSpan(
            text: wordText,
            style: TextStyle(
              backgroundColor: AppColors.accentGold,
              color: Colors.white,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: wordText));
      }
    }

    return spans.isEmpty ? [TextSpan(text: textUthmani)] : spans;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final content = Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            SizedBox(height: 10.h),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final backButton = GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: AppColors.borderLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderMedium, width: 1.w),
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          color: AppColors.textPrimary,
          size: 24.r,
        ),
      ),
    );

    final searchField = Expanded(
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderMedium, width: 1.w),
        ),
        child: Row(
          children: [
            SizedBox(width: 12.w),
            Icon(
              Icons.search_rounded,
              color: AppColors.textPrimary,
              size: 24.r,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppColors.textPrimary,
                ),
                onChanged: _onSearchChanged,
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                textAlign: isAr ? TextAlign.right : TextAlign.left,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  hintStyle: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.38),
                    fontSize: 16.sp,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 8.0.h),
      child: Row(
        children: isAr
            ? [
                backButton,
                SizedBox(width: 12.w),
                searchField,
              ]
            : [
                searchField,
                SizedBox(width: 12.w),
                backButton,
              ],
      ),
    );
  }

  Widget _buildTopicsSection(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 16.h),
          Center(
            child: Icon(
              Icons.search_rounded,
              size: 150.r,
              color: AppColors.accentGold.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 12.h),
          Center(
            child: Text(
              l10n.searchByHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.sp,
                height: 1.6.h,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ),
          SizedBox(height: 90.h),
          Row(
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 26.r,
                color: AppColors.accentGold,
              ),
              SizedBox(width: 8.w),
              Text(
                l10n.topicSectionsTitle,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              mainAxisExtent: 48.h,
            ),
            itemCount: QuranTopics.topics.length,
            itemBuilder: (context, index) {
              final topic = QuranTopics.topics[index];
              final title = topic.getTitle(l10n);
              return GestureDetector(
                onTap: () => _selectTopic(topic),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: AppColors.cardCream,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.3),
                      width: 1.w,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        topic.icon,
                        size: 20.r,
                        color: AppColors.accentGold,
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopicHeader(AppLocalizations l10n) {
    final topicTitle = _selectedTopic!.getTitle(l10n);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      color: AppColors.cardCream.withValues(alpha: 0.5),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedTopic!.icon,
                    size: 20.r,
                    color: AppColors.accentGold,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    topicTitle,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentGold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 22.r,
                  color: AppColors.textPrimary,
                ),
                onPressed: _clearSelectedTopic,
              ),
            ],
          ),
          if (_selectedTopic!.subTopics != null &&
              _selectedTopic!.subTopics!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _selectSubTopic(null),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      margin: EdgeInsets.only(left: 4.w, right: 4.w),
                      decoration: BoxDecoration(
                        color: _selectedSubTopic == null
                            ? AppColors.accentGold
                            : AppColors.cardCream,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: AppColors.accentGold.withValues(alpha: 0.3),
                          width: 1.w,
                        ),
                      ),
                      child: Text(
                        isAr ? 'الكل' : 'All',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: _selectedSubTopic == null
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  ..._selectedTopic!.subTopics!.map((sub) {
                    final isSelected = _selectedSubTopic?.id == sub.id;
                    return GestureDetector(
                      onTap: () => _selectSubTopic(sub),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        margin: EdgeInsets.only(left: 4.w, right: 4.w),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentGold
                              : AppColors.cardCream,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: AppColors.accentGold.withValues(alpha: 0.3),
                            width: 1.w,
                          ),
                        ),
                        child: Text(
                          sub.getName(isAr),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedTopic != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopicHeader(l10n),
          if (_isLoading)
            Expanded(
              child: Center(
                child: CupertinoActivityIndicator(
                  color: AppColors.accentGold,
                  radius: 14.r,
                ),
              ),
            )
          else if (_results.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 52.r,
                      color: AppColors.textPrimary.withValues(alpha: 0.3),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      l10n.noResults,
                      style: TextStyle(
                        fontSize: 18.sp,
                        color: AppColors.textPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(16.r),
                itemCount: _results.length,
                separatorBuilder: (_, _) =>
                    Divider(color: AppColors.divider, height: 1.h),
                itemBuilder: (context, index) {
                  final verse = _results[index];
                  return GestureDetector(
                    onTap: () => _navigateToPage(verse.page, verseKey: verse.verseKey),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.pageListItem(verse.page.toArabicDigits),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textPrimary.withValues(alpha: 0.6),
                                ),
                              ),
                              Text(
                                l10n.surahAndAyah(
                                  QuranMetadata.getSurahName(verse.surah),
                                  verse.ayah.toArabicDigits,
                                ),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentGold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          RichText(
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            text: TextSpan(
                              style: AppTextStyles.quranText.copyWith(
                                fontSize: 22.sp,
                                height: 1.5.h,
                                color: AppColors.textPrimary,
                              ),
                              children: [
                                TextSpan(
                                  text: ArabicTextUtils.removeExtendedUthmaniChars(
                                    verse.textUthmani,
                                  ),
                                ),
                              ],
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
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return _buildTopicsSection(l10n);
    }

    if (_isLoading) {
      return Center(
        child: CupertinoActivityIndicator(
          color: AppColors.accentGold,
          radius: 14.r,
        ),
      );
    }

    if (_isNumericSearch) {
      return _buildNumericResults();
    }

    final matchingSurahs = _getMatchingSurahs(_searchController.text);

    if (_results.isEmpty && matchingSurahs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52.r,
              color: AppColors.textPrimary.withValues(alpha: 0.3),
            ),
            SizedBox(height: 12.h),
            Text(
              l10n.noResults,
              style: TextStyle(
                fontSize: 18.sp,
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    final surahCards = matchingSurahs.map((surahNum) {
      final surahName = QuranMetadata.getSurahName(surahNum);
      final surahPage = _surahPageMap[surahNum] ?? 1;
      return _buildActionCard(
        title: l10n.goToSurahTitle(surahName, surahNum, surahPage),
        icon: Icons.menu_book_rounded,
        onTap: () => _navigateToPage(surahPage),
      );
    }).toList();

    final totalCount = surahCards.length + _results.length;

    return ListView.separated(
      padding: EdgeInsets.all(16.r),
      itemCount: totalCount,
      separatorBuilder: (_, _) =>
          Divider(color: AppColors.divider, height: 1.h),
      itemBuilder: (context, index) {
        if (index < surahCards.length) {
          return surahCards[index];
        }

        final verse = _results[index - surahCards.length];
        return GestureDetector(
          onTap: () => _navigateToPage(verse.page, verseKey: verse.verseKey),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.pageListItem(verse.page.toArabicDigits),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      l10n.surahAndAyah(
                        QuranMetadata.getSurahName(verse.surah),
                        verse.ayah.toArabicDigits,
                      ),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentGold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                RichText(
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  text: TextSpan(
                    style: AppTextStyles.quranText.copyWith(
                      fontSize: 22.sp,
                      height: 1.5.h,
                      color: AppColors.textPrimary,
                    ),
                    children: _getHighlightedUthmani(
                      verse.textClean,
                      ArabicTextUtils.removeExtendedUthmaniChars(
                        verse.textUthmani,
                      ),
                      _searchController.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumericResults() {
    final l10n = AppLocalizations.of(context)!;
    final number =
        int.tryParse(_normalizeArabicNumbers(_searchController.text.trim())) ??
        1;
    final cards = <Widget>[];

    if (number >= 1 && number <= 604) {
      cards.add(
        _buildActionCard(
          title: l10n.goToPageTitle(number),
          icon: Icons.menu_book_rounded,
          onTap: () => _navigateToPage(number),
        ),
      );
    }

    if (number >= 1 && number <= 30) {
      final juzPage = _juzStartPages[number - 1];
      final juzName = QuranMetadata.getJuzName(number);
      cards.add(
        _buildActionCard(
          title: l10n.goToJuzTitle(juzName, number, juzPage),
          icon: Icons.pie_chart_rounded,
          onTap: () => _navigateToPage(juzPage),
        ),
      );
    }

    if (number >= 1 && number <= 114) {
      final surahName = QuranMetadata.getSurahName(number);
      final surahPage = _surahPageMap[number];
      if (surahPage != null) {
        cards.add(
          _buildActionCard(
            title: l10n.goToSurahTitle(surahName, number, surahPage),
            icon: Icons.my_library_books_rounded,
            onTap: () => _navigateToPage(surahPage),
          ),
        );
      } else if (!_surahMapLoaded) {
        cards.add(
          Center(
            child: Padding(
              padding: EdgeInsets.all(8.0.r),
              child: CupertinoActivityIndicator(
                color: AppColors.accentGold,
                radius: 10.r,
              ),
            ),
          ),
        );
      }
    }

    if (cards.isEmpty) {
      return Center(
        child: Text(
          l10n.outOfRange(number.toArabicDigits),
          style: TextStyle(
            fontSize: 16.sp,
            color: AppColors.textPrimary.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      children: cards,
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.cardCream,
      elevation: 0.r,
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: Container(
          width: 44.w,
          height: 44.h,
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accentGold, size: 22.r),
        ),
        title: Text(
          title,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_back_ios_rounded,
          size: 16.r,
          color: AppColors.textPrimary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

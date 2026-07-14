import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../quran_reader/domain/repositories/quran_repository.dart';
import '../../../../../quran_reader/data/models/search_verse_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/constants/quran_metadata.dart';
class QuranSearchScreenDesktop extends StatefulWidget {
  const QuranSearchScreenDesktop({super.key});

  @override
  State<QuranSearchScreenDesktop> createState() => _QuranSearchScreenDesktopState();
}

class _QuranSearchScreenDesktopState extends State<QuranSearchScreenDesktop> {
  final TextEditingController _searchController = TextEditingController();
  late final QuranRepository _repository;

  Timer? _debounce;
  bool _isLoading = false;
  List<SearchVerseModel> _results = [];
  bool _isNumericSearch = false;

  Map<int, int> _surahPageMap = {};
  bool _surahMapLoaded = false;

  static const List<int> _juzStartPages = [
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582
  ];

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _loadSurahPageMap();
  }

  Future<void> _loadSurahPageMap() async {
    final indexResult = await _repository.getSurahsIndex();
    indexResult.fold(
      (f) {
        if (mounted) setState(() => _surahMapLoaded = true);
      },
      (index) {
        final map = <int, int>{};
        for (final row in index) {
          map[row['surah'] as int] = row['start_page'] as int;
        }
        if (mounted) {
          setState(() {
            _surahPageMap = map;
            _surahMapLoaded = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
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

  String _normalizeArabicNumbers(String input) {
    const arabicNumbers = '٠١٢٣٤٥٦٧٨٩';
    const englishNumbers = '0123456789';
    String result = input;
    for (int i = 0; i < arabicNumbers.length; i++) {
      result = result.replaceAll(arabicNumbers[i], englishNumbers[i]);
    }
    return result;
  }

  String _smartNormalize(String text) {
    String c = _normalizeArabicNumbers(text);
    c = c.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u0640]'), '');
    c = c.replaceAll('ـ', '');
    c = c.replaceAll(RegExp(r'[اأإآٱى]'), '');
    c = c.replaceAll(RegExp(r'ة'), 'ه');
    c = c.replaceAll(RegExp(r'[ئ]'), 'ي');
    c = c.replaceAll(RegExp(r'ؤ'), 'و');
    return c;
  }

  List<TextSpan> _getHighlightedUthmani(String textClean, String textUthmani, String query) {
    if (query.isEmpty) return [TextSpan(text: textUthmani)];
    
    final queryWords = query.trim().split(RegExp(r'\s+')).map(_smartNormalize).where((w) => w.isNotEmpty).toList();
    if (queryWords.isEmpty) return [TextSpan(text: textUthmani)];

    final cleanWords = textClean.split(' ');
    final uthmaniWords = textUthmani.split(' ');
    
    int startWordIdx = -1;
    int endWordIdx = -1;
    
    for (int i = 0; i <= cleanWords.length - queryWords.length; i++) {
      bool match = true;
      for (int j = 0; j < queryWords.length; j++) {
        if (!_smartNormalize(cleanWords[i + j]).contains(queryWords[j])) {
          match = false;
          break;
        }
      }
      if (match) {
        startWordIdx = i;
        endWordIdx = i + queryWords.length - 1;
        break;
      }
    }
    
    if (startWordIdx == -1) {
      return [TextSpan(text: textUthmani)];
    }

    final spans = <TextSpan>[];
    
    if (startWordIdx > 0) {
      spans.add(TextSpan(text: '${uthmaniWords.sublist(0, startWordIdx).join(' ')} '));
    }
    
    spans.add(TextSpan(
      text: uthmaniWords.sublist(startWordIdx, (endWordIdx + 1).clamp(0, uthmaniWords.length)).join(' '),
      style: TextStyle(backgroundColor: AppColors.accentGold, color: Colors.white),
    ));
    
    if (endWordIdx < uthmaniWords.length - 1) {
      spans.add(TextSpan(text: ' ${uthmaniWords.sublist(endWordIdx + 1).join(' ')}'));
    }
    
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      backgroundColor: AppColors.surfaceCream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 10),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
    return content;
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderMedium, width: 1),
              ),
              child: Icon(Icons.arrow_forward_rounded, color: AppColors.textPrimary, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.cardCream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderMedium, width: 1),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search_rounded, color: AppColors.textPrimary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                      onChanged: _onSearchChanged,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      autofocus: true,
                      decoration: InputDecoration(
                        
                        hintText: l10n.searchHint,
                        hintStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.38), fontSize: 16),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(bottom: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_searchController.text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(Icons.search_rounded, size: 64, color: AppColors.accentGold.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Center(
              child: Text(
                l10n.searchBy,
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textPrimary.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.searchByHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: AppColors.textPrimary.withValues(alpha: 0.45),
                ),
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accentGold),
      );
    }

    if (_isNumericSearch) {
      return _buildNumericResults();
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 52, color: AppColors.textPrimary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              l10n.noResults,
              style: TextStyle(fontSize: 18, color: AppColors.textPrimary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final verse = _results[index];
        return GestureDetector(
          onTap: () => _navigateToPage(verse.page, verseKey: verse.verseKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.pageListItem(verse.page.toArabicDigits),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      l10n.surahAndAyah(QuranMetadata.getSurahName(verse.surah), verse.ayah.toArabicDigits),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  text: TextSpan(
                    style: AppTextStyles.quranText.copyWith(fontSize: 22, height: 1.5, color: AppColors.textPrimary),
                    children: _getHighlightedUthmani(
                      verse.textClean,
                      ArabicTextUtils.removeExtendedUthmaniChars(verse.textUthmani),
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
    final number = int.tryParse(_normalizeArabicNumbers(_searchController.text.trim())) ?? 1;
    final cards = <Widget>[];

    if (number >= 1 && number <= 604) {
      cards.add(_buildActionCard(
        title: l10n.goToPageTitle(number),
        icon: Icons.menu_book_rounded,
        onTap: () => _navigateToPage(number),
      ));
    }

    if (number >= 1 && number <= 30) {
      final juzPage = _juzStartPages[number - 1];
      final juzName = QuranMetadata.getJuzName(number);
      cards.add(_buildActionCard(
        title: l10n.goToJuzTitle(juzName, number, juzPage),
        icon: Icons.pie_chart_rounded,
        onTap: () => _navigateToPage(juzPage),
      ));
    }

    if (number >= 1 && number <= 114) {
      final surahName = QuranMetadata.getSurahName(number);
      final surahPage = _surahPageMap[number];
      if (surahPage != null) {
        cards.add(_buildActionCard(
          title: l10n.goToSurahTitle(surahName, number, surahPage),
          icon: Icons.my_library_books_rounded,
          onTap: () => _navigateToPage(surahPage),
        ));
      } else if (!_surahMapLoaded) {
        cards.add(Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: AppColors.accentGold, strokeWidth: 2),
          ),
        ));
      }
    }

    if (cards.isEmpty) {
      return Center(
        child: Text(
          l10n.outOfRange(number.toArabicDigits),
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary.withValues(alpha: 0.6)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: cards,
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.cardCream,
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accentGold, size: 22),
        ),
        title: Text(
          title,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_back_ios_rounded,
          size: 16,
          color: AppColors.textPrimary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

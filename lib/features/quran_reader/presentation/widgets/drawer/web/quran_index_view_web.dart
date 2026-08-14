import 'package:flutter/material.dart';
import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/utils/arabic_text_utils.dart';
import '../../../../../../core/constants/quran_metadata.dart';

class QuranIndexViewWeb extends StatefulWidget {
  final int initialIndex;

  const QuranIndexViewWeb({super.key, this.initialIndex = 0});

  @override
  State<QuranIndexViewWeb> createState() => _QuranIndexViewWebState();
}

class _QuranIndexViewWebState extends State<QuranIndexViewWeb>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<int> _juzStartPages = [
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToPage(int pageNumber) => Navigator.pop(context, pageNumber);

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
          l10n.indexTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: AppColors.textPrimary.withValues(alpha: 0.54),
          indicatorColor: AppColors.accentGold,
          labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: l10n.indexSurahsTab),
            Tab(text: l10n.indexJuzsTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SurahListTab(onSelectPage: _navigateToPage),
          _JuzListTab(
            juzStartPages: _juzStartPages,
            onSelectPage: _navigateToPage,
          ),
        ],
      ),
    );
  }
}

class _SurahListTab extends StatefulWidget {
  final ValueChanged<int> onSelectPage;

  const _SurahListTab({required this.onSelectPage});

  @override
  State<_SurahListTab> createState() => _SurahListTabState();
}

class _SurahListTabState extends State<_SurahListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 114,
            separatorBuilder: (context, index) =>
                Divider(color: AppColors.divider, height: 1),
            itemBuilder: (context, index) {
              final surahNum = index + 1;
              final startPage = QuranMetadata.getStartPageForSurah(surahNum);

              return ListTile(
                onTap: () => widget.onSelectPage(startPage),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: _buildCircleNumberBadge('$surahNum'),
                title: Text(
                  l10n.surahListItem(
                    isEn
                        ? QuranMetadata.getSurahNameEnglish(surahNum)
                        : QuranMetadata.getSurahName(surahNum),
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: Text(
                  l10n.pageListItem(
                    isEn ? startPage.toString() : startPage.toArabicDigits,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCircleNumberBadge(String label, {bool filled = true}) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: filled ? 0.12 : 0.1),
        shape: BoxShape.circle,
        border: filled
            ? Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4),
                width: 1,
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.accentGold,
        ),
      ),
    );
  }
}

class _JuzListTab extends StatefulWidget {
  final List<int> juzStartPages;
  final ValueChanged<int> onSelectPage;

  const _JuzListTab({
    required this.juzStartPages,
    required this.onSelectPage,
  });

  @override
  State<_JuzListTab> createState() => _JuzListTabState();
}

class _JuzListTabState extends State<_JuzListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 30,
            separatorBuilder: (context, index) =>
                Divider(color: AppColors.divider, height: 1),
            itemBuilder: (context, index) {
              final juzNum = index + 1;
              final startPage = widget.juzStartPages[index];

              return ListTile(
                onTap: () => widget.onSelectPage(startPage),
                leading: _buildCircleNumberBadge('$juzNum', filled: false),
                title: Text(
                  l10n.juzListItem(
                    isEn ? juzNum.toString() : QuranMetadata.getJuzName(juzNum),
                  ),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                trailing: Text(
                  l10n.pageListItem(
                    isEn ? startPage.toString() : startPage.toArabicDigits,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCircleNumberBadge(String label, {bool filled = true}) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: filled ? 0.12 : 0.1),
        shape: BoxShape.circle,
        border: filled
            ? Border.all(
                color: AppColors.accentGold.withValues(alpha: 0.4),
                width: 1,
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.accentGold,
        ),
      ),
    );
  }
}

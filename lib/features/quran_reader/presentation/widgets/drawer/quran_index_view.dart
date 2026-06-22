import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../quran_reader/domain/repositories/quran_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../quran_metadata.dart';

class QuranIndexView extends StatefulWidget {
  const QuranIndexView({super.key});

  @override
  State<QuranIndexView> createState() => _QuranIndexViewState();
}

class _QuranIndexViewState extends State<QuranIndexView> with SingleTickerProviderStateMixin {
  late final QuranRepository _repository;
  late TabController _tabController;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _surahIndex = [];

  // Approximate start pages for Juz (Madani Mushaf standard)
  final List<int> _juzStartPages = [
    1, 22, 42, 62, 82, 102, 122, 142, 162, 182, 
    202, 222, 242, 262, 282, 302, 322, 342, 362, 382, 
    402, 422, 442, 462, 482, 502, 522, 542, 562, 582
  ];

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _tabController = TabController(length: 2, vsync: this);
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    final indexResult = await _repository.getSurahsIndex();
    indexResult.fold(
      (failure) {
        if (mounted) setState(() => _isLoading = false);
      },
      (index) {
        if (mounted) {
          setState(() {
            _surahIndex = index;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToPage(int pageNumber) {
    Navigator.pop(context, pageNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF5EB),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'الفهرس',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGold,
          unselectedLabelColor: Colors.black54,
          indicatorColor: AppColors.accentGold,
          labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'السور'),
            Tab(text: 'الأجزاء'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSurahList(),
                _buildJuzList(),
              ],
            ),
    );
  }

  Widget _buildSurahList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _surahIndex.length,
      separatorBuilder: (_, _) => const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final surahData = _surahIndex[index];
        final surahNum = surahData['surah'] as int;
        final startPage = surahData['start_page'] as int;
        final surahName = QuranMetadata.getSurahName(surahNum);

        return ListTile(
          onTap: () => _navigateToPage(startPage),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4), width: 1),
            ),
            child: Text(
              '$surahNum',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accentGold),
            ),
          ),
          title: Text(
            'سورة $surahName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          trailing: Text(
            'صفحة $startPage',
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary.withValues(alpha: 0.6)),
          ),
        );
      },
    );
  }

  Widget _buildJuzList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 30,
      separatorBuilder: (_, _) => const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final juzNum = index + 1;
        final startPage = _juzStartPages[index];
        final juzName = QuranMetadata.getJuzName(juzNum);

        return ListTile(
          onTap: () => _navigateToPage(startPage),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$juzNum',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentGold),
            ),
          ),
          title: Text(
            'الجزء $juzName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          trailing: Text(
            'صفحة $startPage',
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary.withValues(alpha: 0.6)),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../quran_reader/domain/repositories/quran_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../quran_metadata.dart';

class QuranFullTafsirView extends StatefulWidget {
  final int pageNumber;

  const QuranFullTafsirView({super.key, required this.pageNumber});

  @override
  State<QuranFullTafsirView> createState() => _QuranFullTafsirViewState();
}

class VerseTafsirData {
  final String verseKey;
  final String textUthmani;
  final String tafsirText;
  final int surah;
  final int ayah;

  VerseTafsirData({
    required this.verseKey,
    required this.textUthmani,
    required this.tafsirText,
    required this.surah,
    required this.ayah,
  });
}

class _QuranFullTafsirViewState extends State<QuranFullTafsirView> {
  late final QuranRepository _repository;
  bool _isLoading = true;
  List<VerseTafsirData> _tafsirList = [];

  @override
  void initState() {
    super.initState();
    _repository = context.read<QuranRepository>();
    _loadTafsir();
  }

  Future<void> _loadTafsir() async {
    try {
      final lines = await _repository.getLinesByPage(widget.pageNumber);
      
      // Extract words and group by verseKey
      final Map<String, List<String>> verseTexts = {};
      final List<String> verseKeys = [];

      for (var line in lines) {
        for (var word in line.words) {
          if (word.charTypeName == 'word') {
            if (!verseTexts.containsKey(word.verseKey)) {
              verseTexts[word.verseKey] = [];
              verseKeys.add(word.verseKey);
            }
            verseTexts[word.verseKey]!.add(word.textUthmani);
          }
        }
      }

      final List<VerseTafsirData> dataList = [];

      for (var vk in verseKeys) {
        final text = verseTexts[vk]!.join(' ');
        final tafsirModel = await _repository.getTafsir(vk);
        final parts = vk.split(':');
        dataList.add(VerseTafsirData(
          verseKey: vk,
          textUthmani: text,
          tafsirText: tafsirModel.text,
          surah: int.tryParse(parts[0]) ?? 1,
          ayah: int.tryParse(parts[1]) ?? 1,
        ));
      }

      setState(() {
        _tafsirList = dataList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5EB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF5EB),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'تفسير الصفحة ${widget.pageNumber}',
          style: const TextStyle(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : _tafsirList.isEmpty
              ? const Center(child: Text('لا يوجد بيانات', style: TextStyle(fontSize: 18, color: AppColors.textPrimary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tafsirList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 24),
                  itemBuilder: (context, index) {
                    final item = _tafsirList[index];
                    final surahName = QuranMetadata.getSurahName(item.surah);
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEFE8DA)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              textDirection: TextDirection.rtl,
                              children: [
                                Text(
                                  'سورة $surahName',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentGold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'آية ${item.ayah}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentGold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${item.textUthmani} ﴿${item.ayah}﴾',
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: AppTextStyles.quranText.copyWith(
                              fontSize: 24,
                              height: 1.8,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: 12),
                          Text(
                            item.tafsirText,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.6,
                              color: AppColors.textPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

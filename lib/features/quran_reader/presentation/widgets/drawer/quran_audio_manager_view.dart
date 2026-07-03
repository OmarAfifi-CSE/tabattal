import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/network/audio_download_manager.dart';
import '../../../../../../l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../quran_metadata.dart';
import '../../../../../core/utils/reciter_localization.dart';

class QuranAudioManagerView extends StatefulWidget {
  const QuranAudioManagerView({super.key});

  @override
  State<QuranAudioManagerView> createState() => _QuranAudioManagerViewState();
}

class _QuranAudioManagerViewState extends State<QuranAudioManagerView> {
  late final AudioDownloadManager _downloadManager;

  String _selectedCategory = AudioDownloadManager.reciterCategories.keys.first;
  late String _selectedReciter;

  // Track download status: 1.0=done, 0.0-0.99=downloading, -1.0=not downloaded
  final Map<int, ValueNotifier<double>> _surahProgress = {};
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _downloadManager = context.read<AudioDownloadManager>();
    _selectedReciter = AudioDownloadManager.reciterCategories[_selectedCategory]!.keys.first;
    _initializeProgressTrackers();
  }

  @override
  void dispose() {
    for (final n in _surahProgress.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeProgressTrackers() async {
    if (!mounted) return;
    setState(() => _isLoadingStatus = true);

    for (int i = 1; i <= 114; i++) {
      _surahProgress[i] ??= ValueNotifier(-1.0);
      _surahProgress[i]!.value = -1.0;
    }

    for (int i = 1; i <= 114; i++) {
      if (!mounted) return;
      final numAyahs = QuranMetadata.surahLengths[i - 1];
      // Use progress (0.0 to 1.0) instead of just bool so partial downloads are shown
      final progress = await _downloadManager.getSurahDownloadProgress(_selectedReciter, i, numAyahs);
      if (progress > 0) {
        _surahProgress[i]!.value = progress; // 1.0=complete, 0.01-0.99=partial
      }
    }

    if (mounted) setState(() => _isLoadingStatus = false);
  }

  void _onReciterChanged(String newReciter) {
    if (_selectedReciter == newReciter) return;
    setState(() => _selectedReciter = newReciter);
    _initializeProgressTrackers();
  }

  Future<void> _downloadSurah(int surah) async {
    final notifier = _surahProgress[surah]!;
    if (notifier.value >= 0 && notifier.value < 1.0) return;
    notifier.value = 0.0;
    final numAyahs = QuranMetadata.surahLengths[surah - 1];
    try {
      await _downloadManager.downloadSurah(
        _selectedReciter,
        surah,
        numAyahs,
        onProgress: (p) => notifier.value = p,
      );
    } catch (e) {
      notifier.value = -1.0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.downloadFailed(QuranMetadata.getSurahName(surah)))),
        );
      }
    }
  }

  Future<void> _downloadAll() async {
    for (int i = 1; i <= 114; i++) {
      if (_surahProgress[i]!.value == -1.0) {
        await _downloadSurah(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reciters = AudioDownloadManager.reciterCategories[_selectedCategory]!.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCream,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.audioManagerTitle,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        // RTL: leading icon is on the right side naturally
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          // ─── Selector Panel Card (same style as surah cards) ──────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category row
                _buildSelectorRow(
                label: AppLocalizations.of(context)!.audioTypeLabel,
                icon: Icons.category_rounded,
                  value: _selectedCategory,
                  items: AudioDownloadManager.reciterCategories.keys.toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                        _selectedReciter = AudioDownloadManager.reciterCategories[val]!.keys.first;
                      });
                      _initializeProgressTrackers();
                    }
                  },
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 10),
                // Reciter row
                _buildSelectorRow(
                  label: AppLocalizations.of(context)!.audioReciterLabel,
                  icon: Icons.mic_rounded,
                  value: _selectedReciter,
                  items: reciters,
                  onChanged: (val) {
                    if (val != null) _onReciterChanged(val);
                  },
                ),
                const SizedBox(height: 14),
                // Download All button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white),
                    label: Text(
                      AppLocalizations.of(context)!.audioDownloadAll,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: _isLoadingStatus ? null : _downloadAll,
                  ),
                ),
              ],
            ),
          ),

          // ─── Surah List ───────────────────────────────────────────────
          if (_isLoadingStatus)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
            )
          else
            ...List.generate(114, (index) => _buildSurahItem(index + 1)),
        ],
      ),
    );
  }

  /// Builds a labeled row with icon + styled dropdown
  Widget _buildSelectorRow({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        // Icon badge
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.accentGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.accentGold, size: 18),
        ),
        const SizedBox(width: 10),
        // Label
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        // Styled inline dropdown
        Expanded(
          child: _InlineDropdown(
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSurahItem(int surah) {
    final surahName = QuranMetadata.getSurahName(surah);
    final notifier = _surahProgress[surah]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: notifier,
        builder: (context, progress, _) {
          final isDownloaded = progress >= 1.0;
          final isDownloading = progress >= 0.0 && progress < 1.0;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$surah',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accentGold),
              ),
            ),
            title: Text(
              'سورة $surahName',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            trailing: isDownloaded
                ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28)
                : isDownloading
                    ? SizedBox(
                        width: 42,
                        height: 42,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade200,
                              color: AppColors.accentGold,
                              strokeWidth: 3,
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.download_rounded),
                        color: AppColors.accentGold,
                        onPressed: () => _downloadSurah(surah),
                      ),
          );
        },
      ),
    );
  }
}

/// A custom inline dropdown that opens directly below the trigger at the same width.
class _InlineDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _InlineDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      splashRadius: 0,
      initialValue: value,
      position: PopupMenuPosition.under,
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.1)),
      ),
      onSelected: onChanged,
      itemBuilder: (context) {
        return items.map((item) {
          final isSelected = item == value;
          return PopupMenuItem<String>(
            value: item,
            height: 40,
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerRight,
              color: isSelected ? AppColors.accentGold.withValues(alpha: 0.1) : Colors.transparent,
              child: Text(
                ReciterLocalization.localize(context, item),
                textAlign: Localizations.localeOf(context).languageCode == 'en' ? TextAlign.left : TextAlign.right,
                textDirection: Localizations.localeOf(context).languageCode == 'en' ? TextDirection.ltr : TextDirection.rtl,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        height: 40,
        width: double.infinity,
        padding: const EdgeInsets.only(left: 14, right: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentGold, size: 22),
            Expanded(
              child: Text(
                ReciterLocalization.localize(context, value),
                textAlign: Localizations.localeOf(context).languageCode == 'en' ? TextAlign.left : TextAlign.right,
                textDirection: Localizations.localeOf(context).languageCode == 'en' ? TextDirection.ltr : TextDirection.rtl,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

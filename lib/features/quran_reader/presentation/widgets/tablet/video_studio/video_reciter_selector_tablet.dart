import 'package:flutter/material.dart';
import '../../../../../../core/constants/reciter_catalog.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';

class VideoReciterSelectorTablet extends StatefulWidget {
  final String selectedReciter;
  final String? selectedCategory;
  final void Function(String name, String category, String path)
      onReciterSelected;

  const VideoReciterSelectorTablet({
    super.key,
    required this.selectedReciter,
    this.selectedCategory,
    required this.onReciterSelected,
  });

  @override
  State<VideoReciterSelectorTablet> createState() =>
      _VideoReciterSelectorTabletState();
}

class _VideoReciterSelectorTabletState
    extends State<VideoReciterSelectorTablet> {
  late String _activeCategory;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.selectedCategory ?? 'مرتل';
  }

  @override
  void didUpdateWidget(covariant VideoReciterSelectorTablet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != null) {
      _activeCategory = widget.selectedCategory!;
    }
  }

  void _showAllRecitersSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppColors.cardCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
            child: Directionality(
              textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
              child: DefaultTabController(
                initialIndex: ReciterCatalog
                    .verifiedVideoRecitersByCategory.keys
                    .toList()
                    .indexOf(_activeCategory)
                    .clamp(
                        0,
                        ReciterCatalog
                                .verifiedVideoRecitersByCategory.keys.length -
                            1),
                length: ReciterCatalog
                    .verifiedVideoRecitersByCategory.keys.length,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_rounded,
                                  color: AppColors.accentGold, size: 20.0),
                              const SizedBox(width: 8.0),
                              Text(
                                l10n.videoStudioChooseReciter,
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      TabBar(
                        labelColor: AppColors.accentGold,
                        unselectedLabelColor:
                            AppColors.textPrimary.withValues(alpha: 0.6),
                        indicatorColor: AppColors.accentGold,
                        labelStyle: const TextStyle(
                            fontSize: 12.0, fontWeight: FontWeight.bold),
                        tabs: ReciterCatalog
                            .verifiedVideoRecitersByCategory.keys
                            .map((cat) => Tab(
                                text: isEn
                                    ? ReciterCatalog.getCategoryNameEnglish(cat)
                                    : cat))
                            .toList(),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: ReciterCatalog
                              .verifiedVideoRecitersByCategory.entries
                              .map((entry) {
                            final cat = entry.key;
                            final reciters = entry.value;

                            return ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              physics: const BouncingScrollPhysics(),
                              itemCount: reciters.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (subCtx, idx) {
                                final item = reciters[idx];
                                final isSelected =
                                    item['name'] == widget.selectedReciter &&
                                        _activeCategory == cat;
                                final reciterDisplayName = isEn
                                    ? ReciterCatalog.getReciterNameEnglish(
                                        item['name']!)
                                    : item['name']!;

                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.record_voice_over_rounded,
                                    color: isSelected
                                        ? AppColors.accentGold
                                        : AppColors.textPrimary
                                            .withValues(alpha: 0.5),
                                    size: 18.0,
                                  ),
                                  title: Text(
                                    reciterDisplayName,
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.accentGold
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.check_circle_rounded,
                                          color: AppColors.accentGold)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _activeCategory = cat;
                                    });
                                    widget.onReciterSelected(
                                        item['name']!, cat, item['path']!);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentReciters =
        ReciterCatalog.verifiedVideoRecitersByCategory[_activeCategory] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header & View All button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  l10n.videoStudioReciter,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => _showAllRecitersSheet(context),
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Text(
                  l10n.videoStudioViewAll,
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentGold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5.0),

        // 2. Category Selector Chips (مرتل / مجود / المصحف المعلم)
        SizedBox(
          height: 28.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount:
                ReciterCatalog.verifiedVideoRecitersByCategory.keys.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6.0),
            itemBuilder: (context, index) {
              final cat = ReciterCatalog.verifiedVideoRecitersByCategory.keys
                  .elementAt(index);
              final isCatSelected = cat == _activeCategory;
              final isEn = Localizations.localeOf(context).languageCode == 'en';

              return InkWell(
                onTap: () {
                  setState(() {
                    _activeCategory = cat;
                  });
                  final reciters =
                      ReciterCatalog.verifiedVideoRecitersByCategory[cat]!;
                  final matchingInCat = reciters
                      .where((r) => r['name'] == widget.selectedReciter)
                      .firstOrNull;
                  if (matchingInCat != null) {
                    widget.onReciterSelected(matchingInCat['name']!, cat,
                        matchingInCat['path']!);
                  } else if (reciters.isNotEmpty) {
                    final first = reciters.first;
                    widget.onReciterSelected(
                        first['name']!, cat, first['path']!);
                  }
                },
                borderRadius: BorderRadius.circular(14.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: isCatSelected
                        ? AppColors.accentGold
                        : AppColors.accentGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: isCatSelected
                          ? AppColors.accentGold
                          : AppColors.accentGold.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isEn ? ReciterCatalog.getCategoryNameEnglish(cat) : cat,
                        style: TextStyle(
                          fontSize: 10.0,
                          fontWeight: isCatSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isCatSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 5.0),

        // 3. Reciters List for the active category
        SizedBox(
          height: 32.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: currentReciters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6.0),
            itemBuilder: (context, index) {
              final reciter = currentReciters[index];
              final isSelected = reciter['name'] == widget.selectedReciter;
              final isEn = Localizations.localeOf(context).languageCode == 'en';
              final reciterDisplayName = isEn
                  ? ReciterCatalog.getReciterNameEnglish(reciter['name']!)
                  : reciter['name']!;

              return InkWell(
                onTap: () {
                  widget.onReciterSelected(
                    reciter['name']!,
                    _activeCategory,
                    reciter['path']!,
                  );
                },
                borderRadius: BorderRadius.circular(16.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentGold
                          : AppColors.accentGold.withValues(alpha: 0.25),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 11.5,
                        color: isSelected
                            ? AppColors.accentGold
                            : AppColors.textPrimary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 5.0),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          reciterDisplayName,
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.accentGold
                                : AppColors.textPrimary,
                            height: 1.15,
                          ),
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
}

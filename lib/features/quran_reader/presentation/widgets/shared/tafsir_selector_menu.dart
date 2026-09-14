import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../bloc/quran_bloc.dart';
import '../../bloc/quran_state.dart';

/// Represents a single selectable Tafsir item in the dropdown menu.
class TafsirOption {
  final int id;
  final String name;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress;

  const TafsirOption({
    required this.id,
    required this.name,
    this.isDownloaded = true,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  static final Set<int> _cachedDownloadedIds = {16};
  static final Map<int, double> _cachedProgressMap = {16: 1.0};

  static Set<int> get cachedDownloadedIds => Set.unmodifiable(_cachedDownloadedIds);
  static Map<int, double> get cachedProgressMap => Map.unmodifiable(_cachedProgressMap);

  static void markDownloaded(int id) {
    _cachedDownloadedIds.add(id);
    _cachedProgressMap[id] = 1.0;
  }

  static void updateProgress(int id, double progress) {
    _cachedProgressMap[id] = progress;
    if (progress >= 0.995) {
      _cachedDownloadedIds.add(id);
    }
  }

  static void registerDownloadedIds(Iterable<int> ids) {
    _cachedDownloadedIds.addAll(ids);
    for (final id in ids) {
      _cachedProgressMap[id] = 1.0;
    }
  }

  /// Factory helper to build the localized list of Tafsir options for the given context.
  static List<TafsirOption> getLocalizedOptions(
    BuildContext context, {
    required Set<int> downloadedIds,
    Map<int, double>? progressMap,
    int? activeDownloadingId,
    double? activeDownloadProgress,
  }) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final l10n = AppLocalizations.of(context)!;

    final rawList = isEn
        ? [
            (169, l10n.tafsirEnIbnKathir),
            (168, l10n.tafsirEnMaarif),
            (817, l10n.tafsirEnTazkirul),
          ]
        : [
            (16, l10n.tafsirAlMuyassar),
            (14, l10n.tafsirIbnKathir),
            (91, l10n.tafsirAlSaadi),
            (15, l10n.tafsirAlTabari),
            (90, l10n.tafsirAlQurtubi),
            (93, l10n.tafsirAlWaseet),
            (94, l10n.tafsirAlBaghawi),
          ];

    return rawList.map((item) {
      final id = item.$1;
      final name = item.$2;
      final isDownloaded = id == 16 ||
          _cachedDownloadedIds.contains(id) ||
          downloadedIds.contains(id) ||
          (_cachedProgressMap[id] != null && _cachedProgressMap[id]! >= 0.995) ||
          (progressMap != null &&
              progressMap.containsKey(id) &&
              progressMap[id]! >= 0.995);

      final isDownloading = !isDownloaded &&
          ((activeDownloadingId == id) ||
              (progressMap != null &&
                  progressMap.containsKey(id) &&
                  progressMap[id]! > 0.0 &&
                  progressMap[id]! < 0.995));

      final progress = activeDownloadingId == id
          ? (activeDownloadProgress ?? 0.0)
          : (progressMap?[id] ?? _cachedProgressMap[id] ?? 0.0);

      return TafsirOption(
        id: id,
        name: name,
        isDownloaded: isDownloaded,
        isDownloading: isDownloading,
        downloadProgress: progress,
      );
    }).toList();
  }

  /// Returns the localized name of a Tafsir by its ID.
  static String getTafsirName(BuildContext context, int id) {
    final l10n = AppLocalizations.of(context)!;
    switch (id) {
      // Arabic tafsirs
      case 16:
        return l10n.tafsirAlMuyassar;
      case 14:
        return l10n.tafsirIbnKathir;
      case 91:
        return l10n.tafsirAlSaadi;
      case 15:
        return l10n.tafsirAlTabari;
      case 90:
        return l10n.tafsirAlQurtubi;
      case 93:
        return l10n.tafsirAlWaseet;
      case 94:
        return l10n.tafsirAlBaghawi;
      // English tafsirs
      case 169:
        return l10n.tafsirEnIbnKathir;
      case 168:
        return l10n.tafsirEnMaarif;
      case 817:
        return l10n.tafsirEnTazkirul;
      default:
        return l10n.tafsirAlMuyassar;
    }
  }
}

/// A smart popup dropdown menu for selecting Tafsir, featuring auto-scrolling
/// to center the active item, custom gold scrollbar, and live download indicators.
class TafsirSelectorMenu extends StatelessWidget {
  final int selectedId;
  final List<TafsirOption> options;
  final ValueChanged<int> onSelected;
  final Widget? trigger;
  final double itemHeight;
  final double? maxHeight;
  final double itemFontSize;
  final double? menuWidth;
  final bool openUpwards;
  final Set<int>? downloadedIds;
  final Map<int, double>? progressMap;
  final int? activeDownloadingId;
  final double? activeDownloadProgress;
  final Listenable? progressListenable;

  const TafsirSelectorMenu({
    super.key,
    required this.selectedId,
    required this.options,
    required this.onSelected,
    this.trigger,
    this.itemHeight = 38.0,
    this.maxHeight,
    this.itemFontSize = 14.0,
    this.menuWidth,
    this.openUpwards = false,
    this.downloadedIds,
    this.progressMap,
    this.activeDownloadingId,
    this.activeDownloadProgress,
    this.progressListenable,
  });

  @override
  Widget build(BuildContext context) {
    final itemH = itemHeight;
    final maxH = maxHeight ?? math.min(220.0, options.length * itemH);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final effectiveWidth = menuWidth ?? (isEn ? 190.0 : 120.0);

    QuranBloc? quranBloc;
    try {
      quranBloc = context.read<QuranBloc>();
    } catch (_) {
      quranBloc = null;
    }

    return PopupMenuButton<int>(
      splashRadius: 0.1,
      position: openUpwards ? PopupMenuPosition.over : PopupMenuPosition.under,
      offset: openUpwards ? Offset(0, -maxH - 6) : const Offset(0, 4),
      color: AppColors.cardCream,
      elevation: 4,
      menuPadding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: effectiveWidth,
        maxWidth: effectiveWidth,
        maxHeight: maxH,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: AppColors.accentGold.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          padding: EdgeInsets.zero,
          height: maxH,
          child: Directionality(
            textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
            child: _TafsirMenuScrollableContent(
              options: options,
              selectedId: selectedId,
              maxHeight: maxH,
              itemHeight: itemH,
              itemFontSize: itemFontSize,
              downloadedIds: downloadedIds,
              initialProgressMap: progressMap,
              activeDownloadingId: activeDownloadingId,
              activeDownloadProgress: activeDownloadProgress,
              progressListenable: progressListenable,
              quranBloc: quranBloc,
            ),
          ),
        ),
      ],
      child: trigger ??
          Padding(
            padding: EdgeInsets.all(8.0.r),
            child: Icon(
              Icons.tune_rounded,
              color: AppColors.accentGold,
              size: 22.r,
            ),
          ),
    );
  }
}

class _TafsirMenuScrollableContent extends StatefulWidget {
  final List<TafsirOption> options;
  final int selectedId;
  final double maxHeight;
  final double itemHeight;
  final double itemFontSize;
  final Set<int>? downloadedIds;
  final Map<int, double>? initialProgressMap;
  final int? activeDownloadingId;
  final double? activeDownloadProgress;
  final Listenable? progressListenable;
  final QuranBloc? quranBloc;

  const _TafsirMenuScrollableContent({
    required this.options,
    required this.selectedId,
    required this.maxHeight,
    required this.itemHeight,
    required this.itemFontSize,
    this.downloadedIds,
    this.initialProgressMap,
    this.activeDownloadingId,
    this.activeDownloadProgress,
    this.progressListenable,
    this.quranBloc,
  });

  @override
  State<_TafsirMenuScrollableContent> createState() =>
      _TafsirMenuScrollableContentState();
}

class _TafsirMenuScrollableContentState
    extends State<_TafsirMenuScrollableContent> {
  late final ScrollController _scrollController;
  late final Map<int, double> _liveProgressMap;
  int? _activeDownloadingId;
  double? _activeDownloadProgress;

  @override
  void initState() {
    super.initState();
    _liveProgressMap = Map<int, double>.from(widget.initialProgressMap ?? {});
    _activeDownloadingId = widget.activeDownloadingId;
    _activeDownloadProgress = widget.activeDownloadProgress;

    for (final opt in widget.options) {
      if (opt.isDownloading) {
        _liveProgressMap[opt.id] = opt.downloadProgress;
        _activeDownloadingId ??= opt.id;
        _activeDownloadProgress ??= opt.downloadProgress;
      } else if (opt.isDownloaded) {
        _liveProgressMap[opt.id] = 1.0;
      }
    }

    final index = widget.options.indexWhere((o) => o.id == widget.selectedId);
    double offset = 0;
    final totalHeight = widget.options.length * widget.itemHeight;
    if (index != -1 && totalHeight > widget.maxHeight) {
      offset = (index * widget.itemHeight) -
          (widget.maxHeight / 2) +
          (widget.itemHeight / 2);
      if (offset < 0) offset = 0;
      final maxScroll = totalHeight - widget.maxHeight;
      if (offset > maxScroll) offset = maxScroll;
    }
    _scrollController = ScrollController(initialScrollOffset: offset);

    widget.progressListenable?.addListener(_onProgressListenableChanged);
  }

  void _onProgressListenableChanged() {
    final listenable = widget.progressListenable;
    if (listenable is ValueListenable<double>) {
      final val = listenable.value;
      _activeDownloadProgress = val;
      if (_activeDownloadingId != null) {
        _liveProgressMap[_activeDownloadingId!] = val;
      }
    } else if (listenable is ValueListenable<Map<int, double>>) {
      final map = listenable.value;
      _liveProgressMap.addAll(map);
      if (_activeDownloadingId != null && map.containsKey(_activeDownloadingId)) {
        _activeDownloadProgress = map[_activeDownloadingId];
      }
    }
    if (widget.initialProgressMap != null) {
      _liveProgressMap.addAll(widget.initialProgressMap!);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.progressListenable?.removeListener(_onProgressListenableChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateLiveStateFromBloc(QuranState quranState) {
    if (quranState is TafsirDownloading) {
      _liveProgressMap[quranState.resourceId] = quranState.progress;
      _activeDownloadingId = quranState.resourceId;
      _activeDownloadProgress = quranState.progress;
      TafsirOption.updateProgress(quranState.resourceId, quranState.progress);
    } else if (quranState is TafsirLoaded) {
      if (quranState.isDownloading) {
        final resId = quranState.effectiveDownloadingResourceId;
        _liveProgressMap[resId] = quranState.downloadProgress;
        _activeDownloadingId = resId;
        _activeDownloadProgress = quranState.downloadProgress;
        TafsirOption.updateProgress(resId, quranState.downloadProgress);
      } else {
        // Download completed or inactive
        final completedId = _activeDownloadingId ?? quranState.tafsir.tafsirId;
        _liveProgressMap[completedId] = 1.0;
        _liveProgressMap[quranState.tafsir.tafsirId] = 1.0;
        TafsirOption.markDownloaded(completedId);
        TafsirOption.markDownloaded(quranState.tafsir.tafsirId);
        _activeDownloadingId = null;
        _activeDownloadProgress = null;
      }
    } else if (quranState is TafsirDownloaded) {
      _liveProgressMap[quranState.resourceId] = 1.0;
      TafsirOption.markDownloaded(quranState.resourceId);
      if (_activeDownloadingId == quranState.resourceId) {
        _activeDownloadingId = null;
        _activeDownloadProgress = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quranBloc != null) {
      return BlocBuilder<QuranBloc, QuranState>(
        bloc: widget.quranBloc,
        buildWhen: (previous, current) {
          return current is TafsirDownloading ||
              current is TafsirLoaded ||
              current is TafsirDownloaded;
        },
        builder: (context, quranState) {
          _updateLiveStateFromBloc(quranState);
          return _buildMenuContent(context);
        },
      );
    }
    return _buildMenuContent(context);
  }

  Widget _buildMenuContent(BuildContext context) {
    final effectiveOptions = TafsirOption.getLocalizedOptions(
      context,
      downloadedIds: widget.downloadedIds ?? const {},
      progressMap: _liveProgressMap,
      activeDownloadingId: _activeDownloadingId,
      activeDownloadProgress: _activeDownloadProgress,
    );

    final totalContentHeight = effectiveOptions.length * widget.itemHeight;
    final contentHeight = math.min(widget.maxHeight, totalContentHeight);

    return SizedBox(
      height: contentHeight,
      child: RawScrollbar(
        controller: _scrollController,
        thumbVisibility:
            effectiveOptions.length * widget.itemHeight > widget.maxHeight,
        thickness: 4.0.w,
        radius: Radius.circular(8.r),
        thumbColor: AppColors.accentGold.withValues(alpha: 0.5),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: effectiveOptions.map((option) {
              final isSelected = option.id == widget.selectedId;
              return InkWell(
                onTap: () => Navigator.pop(context, option.id),
                child: Container(
                  width: MediaQuery.sizeOf(context).width,
                  height: widget.itemHeight,
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  alignment: AlignmentDirectional.centerStart,
                  color: isSelected
                      ? AppColors.accentGold.withValues(alpha: 0.12)
                      : Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isSelected)
                              Padding(
                                padding:
                                    EdgeInsetsDirectional.only(end: 6.w),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: AppColors.accentGold,
                                  size: 16.r,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                option.name,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.menuItemText.copyWith(
                                  fontSize: widget.itemFontSize,
                                  color: isSelected
                                      ? AppColors.accentGold
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (option.isDownloading)
                        Text(
                          '${(option.downloadProgress * 100).toInt()}%',
                          style: AppTextStyles.menuItemText.copyWith(
                            fontSize: widget.itemFontSize - 2,
                            color: AppColors.accentGold,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (!option.isDownloaded)
                        Icon(
                          Icons.download_rounded,
                          size: 16.r,
                          color: AppColors.accentGold.withValues(alpha: 0.7),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

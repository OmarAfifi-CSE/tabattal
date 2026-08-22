import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/quran_metadata.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../data/repositories/video_studio_repository_impl.dart';
import '../../data/services/video_export_service.dart';
import '../../domain/entities/video_enums.dart';
import '../../domain/entities/video_project_config.dart';
import '../bloc/video_studio_bloc.dart';
import '../bloc/video_studio_event.dart';
import '../bloc/video_studio_state.dart';
import '../widgets/video_action_buttons.dart';
import '../widgets/video_aspect_ratio_bar.dart';
import '../widgets/video_export_progress_dialog.dart';
import '../widgets/video_fullscreen_preview_modal.dart';
import '../widgets/video_options_selector.dart';
import '../widgets/video_preview_viewport.dart';
import '../widgets/video_range_picker.dart';
import '../widgets/video_reciter_selector.dart';
import '../widgets/video_theme_selector.dart';

/// Shows the Quran Video Studio modal bottom sheet matching the app theme.
void showQuranVideoStudioModal(
  BuildContext context, {
  required int surahNumber,
  required int startAyah,
  int? endAyah,
  List<VerseModel>? initialVerses,
}) {
  final isWide = MediaQuery.sizeOf(context).width > 600;
  final effectiveEndAyah = endAyah ?? startAyah;

  if (isWide || kIsWeb) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 850),
          child: QuranVideoStudioScreen(
            surahNumber: surahNumber,
            startAyah: startAyah,
            endAyah: effectiveEndAyah,
            initialVerses: initialVerses ?? [],
            isBottomSheet: true,
          ),
        ),
      ),
    );
  } else {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.90;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: QuranVideoStudioScreen(
          surahNumber: surahNumber,
          startAyah: startAyah,
          endAyah: effectiveEndAyah,
          initialVerses: initialVerses ?? [],
          isBottomSheet: true,
        ),
      ),
    );
  }
}

class QuranVideoStudioScreen extends StatelessWidget {
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  final List<VerseModel> initialVerses;
  final bool isBottomSheet;

  const QuranVideoStudioScreen({
    super.key,
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
    required this.initialVerses,
    this.isBottomSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VideoStudioBloc(
        repository: VideoStudioRepositoryImpl(),
        initialConfig: VideoProjectConfig(
          surahNumber: surahNumber,
          startAyah: startAyah,
          endAyah: endAyah,
        ),
      )..add(
          VideoStudioInitRequested(
            surahNumber: surahNumber,
            startAyah: startAyah,
            endAyah: endAyah,
            verses: initialVerses,
          ),
        ),
      child: _QuranVideoStudioView(isBottomSheet: isBottomSheet),
    );
  }
}

class _QuranVideoStudioView extends StatefulWidget {
  final bool isBottomSheet;

  const _QuranVideoStudioView({this.isBottomSheet = false});

  @override
  State<_QuranVideoStudioView> createState() => _QuranVideoStudioViewState();
}

class _QuranVideoStudioViewState extends State<_QuranVideoStudioView> {
  bool _isExportDialogOpen = false;
  BuildContext? _dialogContext;

  void _dismissExportDialog() {
    if (_isExportDialogOpen && _dialogContext != null && _dialogContext!.mounted) {
      _isExportDialogOpen = false;
      Navigator.of(_dialogContext!, rootNavigator: true).pop();
      _dialogContext = null;
    }
  }

  void _showExportDialog(BuildContext context, VideoStudioBloc bloc) {
    if (_isExportDialogOpen) return;
    _isExportDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        _dialogContext = dialogCtx;
        return BlocProvider.value(
          value: bloc,
          child: BlocBuilder<VideoStudioBloc, VideoStudioState>(
            builder: (context, state) {
              return VideoExportProgressDialog(
                progress: state.exportProgress,
                onCancel: () {
                  bloc.add(const VideoStudioExportCancelled());
                  _dismissExportDialog();
                },
                onDismiss: () {
                  _dismissExportDialog();
                },
              );
            },
          ),
        );
      },
    ).then((_) {
      _isExportDialogOpen = false;
      _dialogContext = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VideoStudioBloc, VideoStudioState>(
      listener: (context, state) async {
        if (state.exportProgress.isRendering && !_isExportDialogOpen) {
          _showExportDialog(context, context.read<VideoStudioBloc>());
        } else if (state.exportProgress.isCompleted && _isExportDialogOpen) {
          _dismissExportDialog();

          final outputPath = state.exportProgress.outputPath;
          if (outputPath != null && outputPath.isNotEmpty) {
            if (state.pendingExportAction == VideoExportAction.share) {
              final shareCaption = context.mounted ? AppLocalizations.of(context)?.videoStudioShareCaption ?? 'تلاوة عطرة من تطبيق تبتل' : 'تلاوة عطرة من تطبيق تبتل';
              await VideoExportService.shareOutput(
                filePath: outputPath,
                title: shareCaption,
              );
            } else {
              final saved = await VideoExportService.saveToGallery(filePath: outputPath);
              if (context.mounted) {
                final l10n = AppLocalizations.of(context)!;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      saved
                          ? l10n.videoStudioSavedSuccess
                          : l10n.videoStudioSavedError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: saved ? AppColors.accentGold : Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                );
              }
            }
          }
        }
      },
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final config = state.config;
        final surahName = QuranMetadata.getSurahName(config.surahNumber);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardCream,
              borderRadius: widget.isBottomSheet
                  ? BorderRadius.vertical(top: Radius.circular(24.r))
                  : BorderRadius.zero,
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: AppColors.cardCream,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: Icon(
                    widget.isBottomSheet ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  children: [
                    if (widget.isBottomSheet) ...[
                      Container(
                        width: 36.w,
                        height: 4.h,
                        margin: EdgeInsets.only(bottom: 6.h),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ],
                    Text(
                      l10n.videoStudioTitle,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Amiri',
                      ),
                    ),
                    Text(
                      l10n.videoStudioSurahVerses(surahName, config.startAyah, config.endAyah),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.accentGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            body: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 1. Aspect Ratio Selector
                      Center(
                        child: VideoAspectRatioBar(
                          selectedRatio: config.aspectRatio,
                          onRatioSelected: (ratio) {
                            context
                                .read<VideoStudioBloc>()
                                .add(VideoStudioAspectRatioChanged(ratio));
                          },
                        ),
                      ),

                      SizedBox(height: 12.h),

                      // 2. Interactive Video Viewport Preview
                      VideoPreviewViewport(
                        state: state,
                        onTogglePlay: () {
                          context
                              .read<VideoStudioBloc>()
                              .add(const VideoStudioPlaybackToggled());
                        },
                        onVerseIndexChanged: (index) {
                          context
                              .read<VideoStudioBloc>()
                              .add(VideoStudioActiveVerseIndexChanged(index));
                        },
                        onOpenFullscreen: () {
                          VideoFullscreenPreviewModal.show(context);
                        },
                      ),

                      SizedBox(height: 16.h),

                      // 3. Theme Preset Selector
                      VideoThemeSelector(
                        selectedPreset: config.themePreset,
                        onThemeSelected: (theme) {
                          context
                              .read<VideoStudioBloc>()
                              .add(VideoStudioThemeChanged(theme));
                        },
                      ),

                      SizedBox(height: 14.h),

                      // 4. Ayah Range Selector
                      VideoRangePicker(
                        surahNumber: config.surahNumber,
                        startAyah: config.startAyah,
                        endAyah: config.endAyah,
                        onStartAyahChanged: (start) {
                          context.read<VideoStudioBloc>().add(
                                VideoStudioVerseRangeChanged(
                                  startAyah: start,
                                  endAyah: config.endAyah,
                                  verses: state.verses,
                                ),
                              );
                        },
                        onEndAyahChanged: (end) {
                          context.read<VideoStudioBloc>().add(
                                VideoStudioVerseRangeChanged(
                                  startAyah: config.startAyah,
                                  endAyah: end,
                                  verses: state.verses,
                                ),
                              );
                        },
                      ),

                      SizedBox(height: 14.h),

                      // 5. Reciter Selector
                      VideoReciterSelector(
                        selectedReciter: config.reciterName,
                        onReciterSelected: (name, category, path) {
                          context.read<VideoStudioBloc>().add(
                                VideoStudioReciterChanged(
                                  reciterName: name,
                                  reciterCategory: category,
                                  reciterPath: path,
                                ),
                              );
                        },
                      ),

                      SizedBox(height: 14.h),

                      // 6. Display Options Selector & Quality
                      VideoOptionsSelector(
                        config: config,
                        onQualityChanged: (quality) {
                          context.read<VideoStudioBloc>().add(VideoStudioQualityChanged(quality));
                        },
                        onToggleOption: ({
                          showSurahBadge,
                          showReciterName,
                          showTafsir,
                          showEnglishTranslation,
                          showAudioWaveform,
                        }) {
                          context.read<VideoStudioBloc>().add(
                                VideoStudioOptionToggled(
                                  showSurahBadge: showSurahBadge,
                                  showReciterName: showReciterName,
                                  showTafsir: showTafsir,
                                  showEnglishTranslation: showEnglishTranslation,
                                  showAudioWaveform: showAudioWaveform,
                                ),
                              );
                        },
                      ),

                      SizedBox(height: 24.h),
                    ],
                  ),
                ),

                // 7. Bottom Fixed Action Buttons
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.cardCream,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.accentGold.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: VideoActionButtons(
                      isExporting: state.exportProgress.isRendering,
                      onShareVideo: () {
                        context.read<VideoStudioBloc>().add(
                              const VideoStudioExportStarted(action: VideoExportAction.share),
                            );
                      },
                      onSaveVideo: () {
                        context.read<VideoStudioBloc>().add(
                              const VideoStudioExportStarted(action: VideoExportAction.saveToGallery),
                            );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
}

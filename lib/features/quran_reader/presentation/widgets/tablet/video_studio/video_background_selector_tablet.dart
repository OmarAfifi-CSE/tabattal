import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../quran_video_studio/domain/entities/video_enums.dart';
import '../../../../../quran_video_studio/domain/entities/video_project_config.dart';
import '../../../../../quran_video_studio/presentation/widgets/custom_background_modal.dart';
import '../../../../../quran_video_studio/presentation/widgets/custom_video_modal.dart';

/// Dedicated tablet background selector for video studio.
class VideoBackgroundSelectorTablet extends StatelessWidget {
  final VideoProjectConfig config;
  final ValueChanged<String?> onCustomImageChanged;
  final ValueChanged<String?>? onCustomVideoChanged;
  final ValueChanged<double>? onDimmingChanged;

  const VideoBackgroundSelectorTablet({
    super.key,
    required this.config,
    required this.onCustomImageChanged,
    this.onCustomVideoChanged,
    this.onDimmingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final l10n = AppLocalizations.of(context)!;

    final hasCustomImage = config.backgroundType == VideoBackgroundType.customImage &&
        config.customImagePath != null &&
        config.customImagePath!.isNotEmpty &&
        File(config.customImagePath!).existsSync();

    final hasCustomVideo = config.backgroundType == VideoBackgroundType.customVideo &&
        config.customVideoPath != null &&
        config.customVideoPath!.isNotEmpty &&
        File(config.customVideoPath!).existsSync();

    final isDefaultTheme = !hasCustomImage && !hasCustomVideo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isEn ? 'Video Background' : 'خلفية الفيديو',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (hasCustomVideo)
              Text(
                l10n.videoBgCustomVideoActive,
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold,
                ),
              )
            else if (hasCustomImage)
              Text(
                isEn ? 'Custom Photo Active' : 'صورة مخصصة نشطة',
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentGold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6.0),
        Row(
          children: [
            // Option 1: Default Theme Gradient Background
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (hasCustomImage) {
                    onCustomImageChanged(null);
                  }
                  if (hasCustomVideo) {
                    onCustomVideoChanged?.call(null);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: isDefaultTheme
                        ? AppColors.accentGold.withValues(alpha: 0.12)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isDefaultTheme
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: isDefaultTheme ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDefaultTheme
                            ? Icons.check_circle_rounded
                            : Icons.palette_outlined,
                        size: 15.0,
                        color: isDefaultTheme
                            ? AppColors.accentGold
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5.0),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.videoBgCardDesign,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isDefaultTheme
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isDefaultTheme
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6.0),

            // Option 2: Custom Photo (Gallery / URL)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  CustomBackgroundModal.show(
                    context,
                    currentImagePath: config.customImagePath,
                    onImageSelected: (path) => onCustomImageChanged(path),
                    onImageRemoved: () => onCustomImageChanged(null),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: hasCustomImage
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: hasCustomImage
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: hasCustomImage ? 2.0 : 1.0,
                    ),
                    image: hasCustomImage
                        ? DecorationImage(
                            image: FileImage(File(config.customImagePath!)),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.45),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasCustomImage
                            ? Icons.edit_rounded
                            : Icons.add_photo_alternate_outlined,
                        size: 15.0,
                        color: hasCustomImage
                            ? Colors.white
                            : AppColors.accentGold,
                      ),
                      const SizedBox(width: 5.0),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.videoBgCustomPhoto,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: hasCustomImage
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: hasCustomImage
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6.0),

            // Option 3: Custom Video (Gallery / URL)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  CustomVideoModal.show(
                    context,
                    currentVideoPath: config.customVideoPath,
                    onVideoSelected: (path) => onCustomVideoChanged?.call(path),
                    onVideoRemoved: () => onCustomVideoChanged?.call(null),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: hasCustomVideo
                        ? AppColors.accentGold.withValues(alpha: 0.15)
                        : AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: hasCustomVideo
                          ? AppColors.accentGold
                          : AppColors.divider,
                      width: hasCustomVideo ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasCustomVideo
                            ? Icons.videocam_rounded
                            : Icons.videocam_outlined,
                        size: 15.0,
                        color: hasCustomVideo
                            ? AppColors.accentGold
                            : AppColors.accentGold,
                      ),
                      const SizedBox(width: 5.0),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            hasCustomVideo
                                ? l10n.videoBgChangeVideo
                                : l10n.videoBgCustomVideo,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: hasCustomVideo
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: hasCustomVideo
                                  ? AppColors.accentGold
                                  : AppColors.textPrimary,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

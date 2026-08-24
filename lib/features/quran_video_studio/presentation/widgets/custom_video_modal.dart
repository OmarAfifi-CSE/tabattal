import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/services/custom_video_service.dart';

/// Modal bottom sheet allowing the user to pick a custom background video
/// from the device gallery or via a direct video URL.
class CustomVideoModal extends StatefulWidget {
  final String? currentVideoPath;
  final ValueChanged<String> onVideoSelected;
  final VoidCallback? onVideoRemoved;

  const CustomVideoModal({
    super.key,
    this.currentVideoPath,
    required this.onVideoSelected,
    this.onVideoRemoved,
  });

  static Future<void> show(
    BuildContext context, {
    String? currentVideoPath,
    required ValueChanged<String> onVideoSelected,
    VoidCallback? onVideoRemoved,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardCream,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => CustomVideoModal(
        currentVideoPath: currentVideoPath,
        onVideoSelected: onVideoSelected,
        onVideoRemoved: onVideoRemoved,
      ),
    );
  }

  @override
  State<CustomVideoModal> createState() => _CustomVideoModalState();
}

class _CustomVideoModalState extends State<CustomVideoModal> {
  final TextEditingController _urlController = TextEditingController();
  bool _isUrlInputExpanded = false;
  bool _isLoading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handlePickGallery() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _downloadProgress = 0.0;
    });

    try {
      final path = await CustomVideoService.pickVideoFromGallery();
      if (!mounted) return;
      if (path != null) {
        widget.onVideoSelected(path);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ أثناء اختيار الفيديو: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDownloadUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رابط الفيديو');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _downloadProgress = 0.0;
    });

    try {
      final path = await CustomVideoService.downloadVideoFromUrl(
        url,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _downloadProgress = (received / total).clamp(0.0, 1.0);
            });
          }
        },
      );
      if (!mounted) return;
      widget.onVideoSelected(path);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is FormatException ? e.message : 'فشل تحميل الفيديو من الرابط';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    const errorColor = Color(0xFFD32F2F);

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 12.h,
          bottom: 20.h + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.videocam_rounded,
                      color: AppColors.accentGold,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      l10n.videoBgCustomVideo,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  splashRadius: 20,
                ),
              ],
            ),
            const Divider(height: 1),
            SizedBox(height: 14.h),

            if (_errorMessage != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: errorColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: errorColor,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: errorColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_isLoading) ...[
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        color: AppColors.accentGold,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        _downloadProgress > 0
                            ? '${(_downloadProgress * 100).toInt()}% ${l10n.videoBgLoadingVideo}'
                            : l10n.videoBgLoadingVideo,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Option 1: Pick from Gallery
              _buildOptionTile(
                icon: Icons.video_library_outlined,
                title: l10n.videoBgChooseVideoGallery,
                subtitle: l10n.videoBgChooseVideoGallerySub,
                onTap: _handlePickGallery,
              ),
              SizedBox(height: 10.h),

              // Option 2: Direct Video URL
              _buildOptionTile(
                icon: Icons.link_rounded,
                title: l10n.videoBgVideoUrl,
                subtitle: l10n.videoBgVideoUrlSub,
                onTap: () {
                  setState(() {
                    _isUrlInputExpanded = !_isUrlInputExpanded;
                    _errorMessage = null;
                  });
                },
              ),

              if (_isUrlInputExpanded) ...[
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.accentGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/video.mp4',
                          hintTextDirection: TextDirection.ltr,
                          hintStyle: TextStyle(
                            fontSize: 11.5.sp,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide(
                              color: AppColors.divider,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide(
                              color: AppColors.accentGold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      ElevatedButton.icon(
                        onPressed: _handleDownloadUrl,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(isEn ? 'Load Video' : 'تطبيق الفيديو'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 8.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Option 3: Remove custom video if active
              if (widget.currentVideoPath != null) ...[
                SizedBox(height: 14.h),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onVideoRemoved?.call();
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18.sp,
                    color: errorColor,
                  ),
                  label: Text(
                    l10n.videoBgRemoveVideo,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: errorColor.withValues(alpha: 0.4),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppColors.accentGold.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.accentGold,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.accentGold,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Standardized, premium floating SnackBar for Tabattal app.
/// Matches the Islamic golden-cream & dark theme across all platforms.
class AppSnackBar {
  AppSnackBar._();

  static void showError(BuildContext context, String message) {
    show(
      context,
      message: message,
      isError: true,
      icon: Icons.error_outline_rounded,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(
      context,
      message: message,
      isError: false,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  static void showInfo(BuildContext context, String message, {IconData? icon}) {
    show(
      context,
      message: message,
      isError: false,
      icon: icon ?? Icons.info_outline_rounded,
    );
  }

  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final effectiveIcon = icon ??
        (isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded);

    final errorColor = Colors.red.shade400;
    final successColor = AppColors.accentGold;
    final activeColor = isError ? errorColor : successColor;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  effectiveIcon,
                  color: activeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppColors.cardCream,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: activeColor.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
      ),
    );
  }
}

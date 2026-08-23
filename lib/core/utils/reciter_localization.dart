import 'package:flutter/widgets.dart';
import '../constants/reciter_catalog.dart';

/// Unified utility facade for Reciter and Category localization.
/// Backed by the Single Source of Truth in [ReciterCatalog].
class ReciterLocalization {
  const ReciterLocalization._();

  /// Localize reciter or category name using BuildContext
  static String localize(BuildContext context, String arabicName) =>
      ReciterCatalog.localize(context, arabicName);

  /// Localize reciter or category name using boolean language flag
  static String localizeByLang(bool isEn, String arabicName) =>
      ReciterCatalog.localizeByLang(isEn, arabicName);

  /// Localize category name
  static String localizeCategory(BuildContext context, String category) =>
      ReciterCatalog.localizeCategory(context, category);

  /// Localize reciter name
  static String localizeReciter(BuildContext context, String reciter) =>
      ReciterCatalog.localizeReciter(context, reciter);
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../helpers/verse_card_text_utils.dart';

/// Service responsible for rendering, capturing Ultra-HD PNGs, saving to storage, and sharing.
class VerseCardImageExporter {
  const VerseCardImageExporter._();

  /// Captures the boundary into an Ultra-HD 4.0x scale PNG with solid background.
  static Future<Uint8List?> captureCardPng({
    required GlobalKey repaintKey,
    required Color backgroundColor,
  }) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final double width = boundary.size.width;
      final double height = boundary.size.height;

      const double scale = 4.0;
      final ui.Image rawImage = await boundary.toImage(pixelRatio: scale);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final double targetWidth = (width * scale).floorToDouble();
      final double targetHeight = (height * scale).floorToDouble();

      final paint = Paint()
        ..color = backgroundColor
        ..isAntiAlias = true;
      canvas.drawRect(Rect.fromLTWH(0, 0, targetWidth, targetHeight), paint);

      final imagePaint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      canvas.drawImageRect(
        rawImage,
        Rect.fromLTWH(
          0,
          0,
          rawImage.width.toDouble(),
          rawImage.height.toDouble(),
        ),
        Rect.fromLTWH(0, 0, targetWidth, targetHeight),
        imagePaint,
      );

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        targetWidth.toInt(),
        targetHeight.toInt(),
      );
      final byteData = await finalImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Shares the generated image file.
  static Future<void> shareCard({
    required BuildContext context,
    required Uint8List imageBytes,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    required String fallbackText,
  }) async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahName = isEn
        ? QuranMetadata.getSurahNameEnglish(surahNumber)
        : QuranMetadata.getSurahName(surahNumber);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = startAyah == endAyah
        ? 'Verse_${surahNumber}_${startAyah}_$timestamp.png'
        : 'Verse_${surahNumber}_${startAyah}_to_${endAyah}_$timestamp.png';

    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(imageBytes, mimeType: 'image/png', name: fileName),
          ],
        ),
      );
    } else {
      final tempDir = await getTemporaryDirectory();

      // Clean up previous temporary verse card files
      try {
        final oldFiles = tempDir.listSync().whereType<File>().where(
          (file) => file.path.contains('Verse_') && file.path.endsWith('.png'),
        );
        for (final oldFile in oldFiles) {
          try {
            oldFile.deleteSync();
          } catch (_) {}
        }
      } catch (_) {}

      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      final normalizedPath = Platform.isWindows
          ? tempFile.path.replaceAll('/', '\\')
          : tempFile.path;

      try {
        if (Platform.isWindows) {
          const channel = MethodChannel('dev.fluttercommunity.plus/share');
          await channel.invokeMethod<String>('share', <String, dynamic>{
            'paths': [normalizedPath],
            'mimeTypes': ['image/png'],
            'title': fileName,
            'text': '',
          });
        } else {
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile(
                  normalizedPath,
                  mimeType: 'image/png',
                  name: fileName,
                ),
              ],
            ),
          );
        }
      } on MissingPluginException {
        final shareTitle = isEn ? 'Surah $surahName' : 'سورة $surahName';
        final shareText = isEn
            ? '( $fallbackText ) — Surah $surahName'
            : '﴿ $fallbackText ﴾ — سورة $surahName';
        await SharePlus.instance.share(
          ShareParams(
            title: shareTitle,
            text: shareText,
          ),
        );
      }
    }
  }

  /// Saves the image directly to device storage.
  /// On Desktop (Windows/macOS/Linux), opens the native Save File Dialog so the user can choose destination and filename.
  /// On Mobile, saves to Pictures/Tabattal with MediaStore scan on Android, or Documents on iOS.
  /// Returns `true` if saved successfully, `false` if an error occurred, or `null` if user cancelled.
  static Future<bool?> saveCardImage({
    required Uint8List imageBytes,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    if (kIsWeb) return true;

    final surahName = QuranMetadata.getSurahName(surahNumber);
    final fileName = startAyah == endAyah
        ? 'Tabattal_${surahName}_$startAyah'
        : 'Tabattal_${surahName}_${startAyah}_to_$endAyah';

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final saveLocation = await getSaveLocation(
          suggestedName: '$fileName.png',
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'PNG Image',
              extensions: ['png'],
              mimeTypes: ['image/png'],
            ),
          ],
        );

        if (saveLocation == null) {
          return null; // User dismissed save dialog
        }

        final destinationFile = File(saveLocation.path);
        final parentDir = destinationFile.parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        await destinationFile.writeAsBytes(imageBytes);
        return true;
      } catch (e) {
        debugPrint('Desktop saveCardImage error: $e');
        return false;
      }
    } else if (!kIsWeb && Platform.isAndroid) {
      try {
        final picturesDir = Directory('/storage/emulated/0/Pictures/Tabattal');
        if (!picturesDir.existsSync()) {
          picturesDir.createSync(recursive: true);
        }
        final picFile = File('${picturesDir.path}/$fileName.png');
        await picFile.writeAsBytes(imageBytes);

        const channel = MethodChannel('com.omarafifi.tabattal/media_scanner');
        await channel.invokeMethod('scanFile', {'path': picFile.path});
        return true;
      } catch (_) {
        return false;
      }
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/$fileName.png');
      await file.writeAsBytes(imageBytes);
      return true;
    }
  }

  /// Builds formatted share text for clipboard copying.
  static String getFormattedShareText({
    required BuildContext context,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    required String verseTextUthmani,
    required bool includeTafsir,
    required String tafsirText,
    required bool includeTranslation,
    required String translationText,
  }) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final surahName = isEn
        ? QuranMetadata.getSurahNameEnglish(surahNumber)
        : QuranMetadata.getSurahName(surahNumber);
    final l10n = AppLocalizations.of(context)!;

    final rangeText = startAyah == endAyah
        ? l10n.verseCardSurahSingleAyah(
            surahName,
            isEn ? '$startAyah' : VerseCardTextUtils.toArabicDigits(startAyah),
          )
        : l10n.verseCardSurahMultipleAyahs(
            surahName,
            isEn ? '$startAyah' : VerseCardTextUtils.toArabicDigits(startAyah),
            isEn ? '$endAyah' : VerseCardTextUtils.toArabicDigits(endAyah),
          );

    final buffer = StringBuffer();
    buffer.writeln('( $verseTextUthmani )');
    buffer.writeln();

    if (includeTafsir && tafsirText.trim().isNotEmpty) {
      buffer.writeln('【 ${l10n.verseCardTafsirBadge} 】');
      buffer.writeln(tafsirText.trim());
      buffer.writeln();
    }

    if (includeTranslation && translationText.trim().isNotEmpty) {
      buffer.writeln('【 ${l10n.verseCardTranslationBadge} 】');
      buffer.writeln(translationText.trim());
      buffer.writeln();
    }

    buffer.writeln(rangeText);
    return buffer.toString();
  }
}

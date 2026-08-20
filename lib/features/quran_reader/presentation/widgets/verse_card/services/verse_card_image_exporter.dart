import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../../core/constants/quran_metadata.dart';
import '../../../../../../l10n/app_localizations.dart';

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
      await Share.shareXFiles([
        XFile.fromData(imageBytes, mimeType: 'image/png', name: fileName),
      ]);
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

      try {
        await Share.shareXFiles([XFile(tempFile.path, mimeType: 'image/png')]);
      } on MissingPluginException {
        await Share.share(
          isEn
              ? '( $fallbackText ) — Surah $surahName'
              : '﴿ $fallbackText ﴾ — سورة $surahName',
        );
      }
    }
  }

  /// Saves the image directly to device storage.
  static Future<bool> saveCardImage({
    required Uint8List imageBytes,
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    if (kIsWeb) return true;

    final fileName = startAyah == endAyah
        ? 'Verse_${surahNumber}_$startAyah'
        : 'Verse_${surahNumber}_${startAyah}_to_$endAyah';

    if (Platform.isAndroid) {
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
        ? (isEn
              ? 'Surah $surahName • Ayah $startAyah'
              : 'سورة $surahName • آية $startAyah')
        : (isEn
              ? 'Surah $surahName • Ayahs $startAyah - $endAyah'
              : 'سورة $surahName • الآيات ($startAyah - $endAyah)');

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

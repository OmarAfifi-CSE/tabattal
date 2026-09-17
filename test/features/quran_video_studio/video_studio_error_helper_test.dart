import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabattal/l10n/app_localizations.dart';
import 'package:tabattal/features/quran_video_studio/presentation/utils/video_studio_error_helper.dart';

void main() {
  Widget buildTestWidget({
    required Locale locale,
    required void Function(BuildContext context) onContext,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      home: Builder(
        builder: (context) {
          onContext(context);
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    );
  }

  group('VideoStudioErrorHelper Localization Tests', () {
    testWidgets('Translates network errors properly in Arabic and English', (tester) async {
      late BuildContext arContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('ar'),
        onContext: (ctx) => arContext = ctx,
      ));
      await tester.pumpAndSettle();

      final arResult = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'SocketException: Failed host lookup: api.quran.com',
      );
      expect(arResult, contains('تعذر الاتصال بالخادم'));

      late BuildContext enContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('en'),
        onContext: (ctx) => enContext = ctx,
      ));
      await tester.pumpAndSettle();

      final enResult = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'DioException [connection error]: connection refused',
      );
      expect(enResult, contains('Could not connect to the server'));
    });

    testWidgets('Translates unverified reciter timing errors in Arabic and English', (tester) async {
      late BuildContext arContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('ar'),
        onContext: (ctx) => arContext = ctx,
      ));
      await tester.pumpAndSettle();

      final arResult = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'لا تتوفر تسجيلات توقيت حقيقية بالكلمة للقارئ المختار (MaherAlMuaiqly128kbps)',
      );
      expect(arResult, contains('لا تتوفر تسجيلات توقيت دقيقة'));

      late BuildContext enContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('en'),
        onContext: (ctx) => enContext = ctx,
      ));
      await tester.pumpAndSettle();

      final enResult = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'Reciter timing unavailable for MaherAlMuaiqly128kbps',
      );
      expect(enResult, contains('Authentic word-by-word timing is not available'));
    });

    testWidgets('Translates verse timing fetch errors in Arabic and English', (tester) async {
      late BuildContext arContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('ar'),
        onContext: (ctx) => arContext = ctx,
      ));
      await tester.pumpAndSettle();

      final arResult = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'تعذر جلب التوقيت الحقيقي الدقيق لآية 2:255',
      );
      expect(arResult, contains('تعذر جلب التوقيت الحقيقي الدقيق'));

      late BuildContext enContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('en'),
        onContext: (ctx) => enContext = ctx,
      ));
      await tester.pumpAndSettle();

      final enResult = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'Failed to fetch authentic word timing segments for verse 2:255',
      );
      expect(enResult, contains('Could not retrieve authentic word timing'));
    });

    testWidgets('Translates audio download and cancelled errors in Arabic and English', (tester) async {
      late BuildContext arContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('ar'),
        onContext: (ctx) => arContext = ctx,
      ));
      await tester.pumpAndSettle();

      final arCancel = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'Audio preparation cancelled',
      );
      expect(arCancel, contains('تم إلغاء تجهيز الملفات الصوتية'));

      final arDownload = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'Failed to download audio file',
      );
      expect(arDownload, contains('تعذر تنزيل الملف الصوتي'));
    });

    testWidgets('Translates encoding and web browser errors in Arabic and English', (tester) async {
      late BuildContext arContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('ar'),
        onContext: (ctx) => arContext = ctx,
      ));
      await tester.pumpAndSettle();

      final arFfmpeg = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'FFmpeg execution failed with code 1',
      );
      expect(arFfmpeg, contains('معالجة وترميز الفيديو'));

      final arWeb = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'MediaRecorder is not supported in this browser',
      );
      expect(arWeb, contains('في هذا المتصفح'));
    });

    testWidgets('Translates file too large, port 8080, and video validation errors accurately in Arabic and English', (tester) async {
      late BuildContext arContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('ar'),
        onContext: (ctx) => arContext = ctx,
      ));
      await tester.pumpAndSettle();

      final arLimit = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'MulterError: File too large (LIMIT_FILE_SIZE)',
      );
      expect(arLimit, contains('150 ميجابايت'));

      final ar413 = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'HTTP 413: Payload Too Large',
      );
      expect(ar413, contains('150 ميجابايت'));

      final arServiceOffline = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'تعذر الاتصال بخادم تصدير الفيديو على المنفذ 8080. يُرجى التحقق من تشغيل السيرفر والمحاولة مجددًا.',
      );
      expect(arServiceOffline, contains('8080'));

      final arServerProcessing = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'حدث خطأ أثناء معالجة الفيديو في السيرفر (كود 500)',
      );
      expect(arServerProcessing, contains('معالجة'));

      final arInvalidUrl = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'INVALID_URL',
      );
      expect(arInvalidUrl, contains('http'));

      final arEmptyFile = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'EMPTY_FILE',
      );
      expect(arEmptyFile, contains('فارغ'));

      late BuildContext enContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('en'),
        onContext: (ctx) => enContext = ctx,
      ));
      await tester.pumpAndSettle();

      final enLimit = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'FILE_TOO_LARGE: 160.0 MB (limit: 150 MB)',
      );
      expect(enLimit, contains('150 MB'));

      final enServiceOffline = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'Connection refused on 8080',
      );
      expect(enServiceOffline, contains('8080'));

      final enInvalidUrl = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'INVALID_URL',
      );
      expect(enInvalidUrl, contains('http'));

      final enEmptyFile = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'EMPTY_FILE',
      );
      expect(enEmptyFile, contains('empty'));
    });

    testWidgets('Translates duration measurement, missing files, frame creation, and surah errors in Arabic and English', (tester) async {
      late BuildContext arContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('ar'),
        onContext: (ctx) => arContext = ctx,
      ));
      await tester.pumpAndSettle();

      // Duration measurement for ayah 3 (contains "الإنترنت" but should map to duration measurement error)
      final arMeasure = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'تعذر قياس مدة المقطع الصوتي بدقة للآية 3. يُرجى التحقق من الاتصال بالإنترنت أو توفر الملف الصوتي.',
      );
      expect(arMeasure, contains('3'));
      expect(arMeasure, contains('قياس'));

      // Audio file for ayah 5 not found
      final arFileNotFound = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'تعذر العثور على الملف الصوتي للآية 5',
      );
      expect(arFileNotFound, contains('5'));
      expect(arFileNotFound, contains('الملف الصوتي'));

      // Surah not downloaded
      final arSurah = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'السورة غير محملة محليًا على الجهاز للقارئ المحدد',
      );
      expect(arSurah, contains('محملة'));

      // Base card frame failure
      final arBaseFrame = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'Failed to create base card frame',
      );
      expect(arBaseFrame, contains('الإطار الأساسي'));

      // Verse text render failure
      final arRenderText = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'Failed to render text for verse 7',
      );
      expect(arRenderText, contains('7'));

      // Timeline incomplete
      final arTimeline = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'قائمة مدد الآيات غير مكتملة',
      );
      expect(arTimeline, contains('قائمة مدد'));

      // Technical stacktrace in Arabic context does not leak raw text
      final arRawException = VideoStudioErrorHelper.getLocalizedError(
        arContext,
        'Exception: Something went wrong at line 42 with stack trace: ...',
      );
      expect(arRawException, isNot(contains('stack trace')));
      expect(arRawException, contains('تعذر'));

      // English Context
      late BuildContext enContext;
      await tester.pumpWidget(buildTestWidget(
        locale: const Locale('en'),
        onContext: (ctx) => enContext = ctx,
      ));
      await tester.pumpAndSettle();

      final enMeasure = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'تعذر قياس مدة المقطع الصوتي بدقة للآية 3',
      );
      expect(enMeasure, contains('3'));
      expect(enMeasure, contains('measure'));

      final enFileNotFound = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'Audio file for ayah 5 not found',
      );
      expect(enFileNotFound, contains('5'));
      expect(enFileNotFound, contains('Audio file'));

      final enSurah = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'السورة غير محملة محليًا على الجهاز للقارئ المحدد',
      );
      expect(enSurah, contains('surah is not downloaded'));

      final enBaseFrame = VideoStudioErrorHelper.getLocalizedError(
        enContext,
        'فشل في إنشاء الإطار الأساسي للبطاقة',
      );
      expect(enBaseFrame, contains('base card frame'));
    });
  });
}

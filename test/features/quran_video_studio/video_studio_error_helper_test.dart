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
  });
}

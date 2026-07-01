// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'تبتل';

  @override
  String get drawerSearch => 'البحث المتقدم';

  @override
  String get drawerSearchSubtitle => 'بحث في النصوص والأرقام';

  @override
  String get drawerIndex => 'الفهرس';

  @override
  String get drawerIndexSubtitle => 'السور والأجزاء';

  @override
  String get drawerBookmarks => 'العلامات المرجعية';

  @override
  String get drawerBookmarksSubtitle => 'الآيات المحفوظة';

  @override
  String get drawerTafsir => 'التفسير الكامل';

  @override
  String get drawerTafsirSubtitle => 'تفسير لجميع الآيات والسور';

  @override
  String get drawerTranslation => 'الترجمة الإنجليزية';

  @override
  String get drawerTranslationSubtitle => 'ترجمة لمعاني القرآن';

  @override
  String get drawerAudioManager => 'مدير الصوتيات';

  @override
  String get drawerAudioManagerSubtitle => 'تحميل وإدارة التلاوات';

  @override
  String get drawerLanguage => 'اللغة';

  @override
  String get drawerLanguageSubtitle => 'العربية / English';

  @override
  String get menuTafsir => 'التفسير';

  @override
  String get menuTafsirTitle => 'التفسير - الميسر';

  @override
  String get menuTranslation => 'الترجمة';

  @override
  String get menuListen => 'الاستماع للآيات';

  @override
  String get menuGoToVerse => 'انتقال التلاوة لهذه الآية';

  @override
  String get menuBookmarkAdd => 'إضافة علامة مرجعية';

  @override
  String get menuBookmarkRemove => 'إزالة العلامة المرجعية';

  @override
  String get menuShare => 'نشر';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get noBookmarks => 'لا توجد علامات مرجعية';

  @override
  String get noBookmarksHint => 'اضغط على أي آية لإضافتها كعلامة مرجعية';

  @override
  String get noResults => 'لم يتم العثور على نتائج';

  @override
  String get searchHint => 'البحث بالنصوص أو الأرقام...';

  @override
  String get searchBy => 'ابحث عن طريق';

  @override
  String get searchByHint =>
      'رقم الصفحة • رقم الجزء • رقم السورة\nأو النص القرآني';

  @override
  String get pagePrefix => 'صفحة';

  @override
  String get surahPrefix => 'سورة';

  @override
  String get juzPrefix => 'الجزء';

  @override
  String get ayahPrefix => 'الآية';

  @override
  String get audioTypeLabel => 'النوع';

  @override
  String get audioReciterLabel => 'القارئ';

  @override
  String get audioRepeatLabel => 'تكرار الآية';

  @override
  String get audioRepeatContinuous => 'تكرار مستمر للآية';

  @override
  String get audioRepeatNone => 'بدون تكرار (استمرار)';

  @override
  String get audioRepeatTwice => 'تكرار مرتين';

  @override
  String get audioRepeatThrice => 'تكرار ثلاث مرات';

  @override
  String get audioStartListening => 'ابدأ الاستماع';

  @override
  String get audioSaveSettings => 'حفظ الإعدادات';

  @override
  String get audioSettingsTitle => 'إعدادات الاستماع';

  @override
  String get audioDownloadAll => 'تحميل المصحف كامل';

  @override
  String get audioManagerTitle => 'مدير الصوتيات';

  @override
  String get timerStop => 'إيقاف المؤقت';

  @override
  String get timerMinutes5 => '5 دقائق';

  @override
  String get timerMinutes10 => '10 دقائق';

  @override
  String get timerMinutes15 => '15 دقيقة';

  @override
  String get timerMinutes30 => '30 دقيقة';

  @override
  String get timerMinutes60 => '60 دقيقة';

  @override
  String get indexSurahsTab => 'السور';

  @override
  String get indexJuzsTab => 'الأجزاء';

  @override
  String downloadingTafsir(int percent) {
    return 'جاري تحميل التفسير... $percent%';
  }

  @override
  String get downloadingTafsirBackground =>
      'جاري تحميل باقي التفسير في الخلفية...';

  @override
  String get tafsirNotAvailableLocally => 'تفسير هذه الآية غير متوفر محلياً';

  @override
  String tafsirPartialDownloadHint(int percent) {
    return 'تم تحميل $percent% من التفسير. هل ترغب في استكمال التحميل؟';
  }

  @override
  String get continueDownload => 'استكمال التحميل';

  @override
  String get noLocalData => 'لا يوجد بيانات في قاعدة البيانات المحلية';

  @override
  String get noLocalTranslation => 'لا يوجد ترجمة في قاعدة البيانات المحلية';

  @override
  String get noTafsirAvailable => 'لا يوجد تفسير متاح';

  @override
  String get indexLoadError => 'فشل تحميل الفهرس';

  @override
  String downloadFailed(String name) {
    return 'فشل التحميل: $name';
  }

  @override
  String get downloadFailedInternet =>
      'فشل تحميل التفسير. يرجى التأكد من اتصالك بالإنترنت.';

  @override
  String get fullTafsirTitle => 'التفسير الشامل';

  @override
  String get translationTitle => 'الترجمة';

  @override
  String get bookmarksTitle => 'العلامات المرجعية';

  @override
  String get indexTitle => 'الفهرس';

  @override
  String surahBookmarkTitle(String name) {
    return 'سورة $name';
  }

  @override
  String verseBookmarkSubtitle(String ayah, String page) {
    return 'الآية $ayah  •  صفحة $page';
  }

  @override
  String goToPageTitle(int num) {
    return 'الذهاب للصفحة $num';
  }

  @override
  String goToJuzTitle(String name, int num, int page) {
    return 'الذهاب للجزء $name ($num) — صفحة $page';
  }

  @override
  String goToSurahTitle(String name, int num, int page) {
    return 'الذهاب لسورة $name ($num) — صفحة $page';
  }

  @override
  String outOfRange(String num) {
    return 'الرقم $num خارج النطاق المتاح';
  }

  @override
  String surahListItem(String name) {
    return 'سورة $name';
  }

  @override
  String juzListItem(String name) {
    return 'الجزء $name';
  }

  @override
  String pageListItem(String page) {
    return 'صفحة $page';
  }

  @override
  String surahAndAyah(String surah, String ayah) {
    return 'سورة $surah - آية $ayah';
  }

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePickerTitle => 'اختر اللغة';

  @override
  String sleepTimerStopped(int minutes) {
    return 'سيتم إيقاف التلاوة بعد $minutes دقائق';
  }
}

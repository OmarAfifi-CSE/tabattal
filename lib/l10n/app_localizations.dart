import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'تبتل'**
  String get appName;

  /// No description provided for @drawerSearch.
  ///
  /// In ar, this message translates to:
  /// **'البحث المتقدم'**
  String get drawerSearch;

  /// No description provided for @drawerSearchSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'بحث في النصوص والأرقام'**
  String get drawerSearchSubtitle;

  /// No description provided for @drawerIndex.
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get drawerIndex;

  /// No description provided for @drawerIndexSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'السور والأجزاء'**
  String get drawerIndexSubtitle;

  /// No description provided for @drawerBookmarks.
  ///
  /// In ar, this message translates to:
  /// **'العلامات المرجعية'**
  String get drawerBookmarks;

  /// No description provided for @drawerBookmarksSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الآيات المحفوظة'**
  String get drawerBookmarksSubtitle;

  /// No description provided for @drawerTafsir.
  ///
  /// In ar, this message translates to:
  /// **'التفسير الكامل'**
  String get drawerTafsir;

  /// No description provided for @drawerTafsirSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تفسير لجميع الآيات والسور'**
  String get drawerTafsirSubtitle;

  /// No description provided for @drawerTranslation.
  ///
  /// In ar, this message translates to:
  /// **'الترجمة الإنجليزية'**
  String get drawerTranslation;

  /// No description provided for @drawerTranslationSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ترجمة لمعاني القرآن'**
  String get drawerTranslationSubtitle;

  /// No description provided for @drawerAudioManager.
  ///
  /// In ar, this message translates to:
  /// **'مدير الصوتيات'**
  String get drawerAudioManager;

  /// No description provided for @drawerAudioManagerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تحميل وإدارة التلاوات'**
  String get drawerAudioManagerSubtitle;

  /// No description provided for @drawerLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get drawerLanguage;

  /// No description provided for @drawerLanguageSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'العربية / English'**
  String get drawerLanguageSubtitle;

  /// No description provided for @menuTafsir.
  ///
  /// In ar, this message translates to:
  /// **'التفسير'**
  String get menuTafsir;

  /// No description provided for @menuTafsirTitle.
  ///
  /// In ar, this message translates to:
  /// **'التفسير - الميسر'**
  String get menuTafsirTitle;

  /// No description provided for @menuTranslation.
  ///
  /// In ar, this message translates to:
  /// **'الترجمة'**
  String get menuTranslation;

  /// No description provided for @menuListen.
  ///
  /// In ar, this message translates to:
  /// **'الاستماع للآيات'**
  String get menuListen;

  /// No description provided for @menuGoToVerse.
  ///
  /// In ar, this message translates to:
  /// **'انتقال التلاوة لهذه الآية'**
  String get menuGoToVerse;

  /// No description provided for @menuBookmarkAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة علامة مرجعية'**
  String get menuBookmarkAdd;

  /// No description provided for @menuBookmarkRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة العلامة المرجعية'**
  String get menuBookmarkRemove;

  /// No description provided for @menuShare.
  ///
  /// In ar, this message translates to:
  /// **'نشر'**
  String get menuShare;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @noBookmarks.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد علامات مرجعية'**
  String get noBookmarks;

  /// No description provided for @noBookmarksHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على أي آية لإضافتها كعلامة مرجعية'**
  String get noBookmarksHint;

  /// No description provided for @noResults.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على نتائج'**
  String get noResults;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'البحث بالنصوص أو الأرقام...'**
  String get searchHint;

  /// No description provided for @searchBy.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن طريق'**
  String get searchBy;

  /// No description provided for @searchByHint.
  ///
  /// In ar, this message translates to:
  /// **'رقم الصفحة • رقم الجزء • رقم السورة\nأو النص القرآني'**
  String get searchByHint;

  /// No description provided for @pagePrefix.
  ///
  /// In ar, this message translates to:
  /// **'صفحة'**
  String get pagePrefix;

  /// No description provided for @surahPrefix.
  ///
  /// In ar, this message translates to:
  /// **'سورة'**
  String get surahPrefix;

  /// No description provided for @juzPrefix.
  ///
  /// In ar, this message translates to:
  /// **'الجزء'**
  String get juzPrefix;

  /// No description provided for @ayahPrefix.
  ///
  /// In ar, this message translates to:
  /// **'الآية'**
  String get ayahPrefix;

  /// No description provided for @audioTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get audioTypeLabel;

  /// No description provided for @audioReciterLabel.
  ///
  /// In ar, this message translates to:
  /// **'القارئ'**
  String get audioReciterLabel;

  /// No description provided for @audioRepeatLabel.
  ///
  /// In ar, this message translates to:
  /// **'تكرار الآية'**
  String get audioRepeatLabel;

  /// No description provided for @audioRepeatContinuous.
  ///
  /// In ar, this message translates to:
  /// **'تكرار مستمر للآية'**
  String get audioRepeatContinuous;

  /// No description provided for @audioRepeatNone.
  ///
  /// In ar, this message translates to:
  /// **'بدون تكرار (استمرار)'**
  String get audioRepeatNone;

  /// No description provided for @audioRepeatTwice.
  ///
  /// In ar, this message translates to:
  /// **'تكرار مرتين'**
  String get audioRepeatTwice;

  /// No description provided for @audioRepeatThrice.
  ///
  /// In ar, this message translates to:
  /// **'تكرار ثلاث مرات'**
  String get audioRepeatThrice;

  /// No description provided for @audioStartListening.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الاستماع'**
  String get audioStartListening;

  /// No description provided for @audioSaveSettings.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الإعدادات'**
  String get audioSaveSettings;

  /// No description provided for @audioSettingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الاستماع'**
  String get audioSettingsTitle;

  /// No description provided for @audioDownloadAll.
  ///
  /// In ar, this message translates to:
  /// **'تحميل المصحف كامل'**
  String get audioDownloadAll;

  /// No description provided for @audioManagerTitle.
  ///
  /// In ar, this message translates to:
  /// **'مدير الصوتيات'**
  String get audioManagerTitle;

  /// No description provided for @timerStop.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف المؤقت'**
  String get timerStop;

  /// No description provided for @timerMinutes5.
  ///
  /// In ar, this message translates to:
  /// **'5 دقائق'**
  String get timerMinutes5;

  /// No description provided for @timerMinutes10.
  ///
  /// In ar, this message translates to:
  /// **'10 دقائق'**
  String get timerMinutes10;

  /// No description provided for @timerMinutes15.
  ///
  /// In ar, this message translates to:
  /// **'15 دقيقة'**
  String get timerMinutes15;

  /// No description provided for @timerMinutes30.
  ///
  /// In ar, this message translates to:
  /// **'30 دقيقة'**
  String get timerMinutes30;

  /// No description provided for @timerMinutes60.
  ///
  /// In ar, this message translates to:
  /// **'60 دقيقة'**
  String get timerMinutes60;

  /// No description provided for @indexSurahsTab.
  ///
  /// In ar, this message translates to:
  /// **'السور'**
  String get indexSurahsTab;

  /// No description provided for @indexJuzsTab.
  ///
  /// In ar, this message translates to:
  /// **'الأجزاء'**
  String get indexJuzsTab;

  /// No description provided for @downloadingTafsir.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل التفسير... {percent}%'**
  String downloadingTafsir(int percent);

  /// No description provided for @downloadingTafsirBackground.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحميل باقي التفسير في الخلفية...'**
  String get downloadingTafsirBackground;

  /// No description provided for @tafsirNotAvailableLocally.
  ///
  /// In ar, this message translates to:
  /// **'تفسير هذه الآية غير متوفر محلياً'**
  String get tafsirNotAvailableLocally;

  /// No description provided for @tafsirPartialDownloadHint.
  ///
  /// In ar, this message translates to:
  /// **'تم تحميل {percent}% من التفسير. هل ترغب في استكمال التحميل؟'**
  String tafsirPartialDownloadHint(int percent);

  /// No description provided for @continueDownload.
  ///
  /// In ar, this message translates to:
  /// **'استكمال التحميل'**
  String get continueDownload;

  /// No description provided for @noLocalData.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد بيانات في قاعدة البيانات المحلية'**
  String get noLocalData;

  /// No description provided for @noLocalTranslation.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد ترجمة في قاعدة البيانات المحلية'**
  String get noLocalTranslation;

  /// No description provided for @noTafsirAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد تفسير متاح'**
  String get noTafsirAvailable;

  /// No description provided for @indexLoadError.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحميل الفهرس'**
  String get indexLoadError;

  /// No description provided for @downloadFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التحميل: {name}'**
  String downloadFailed(String name);

  /// No description provided for @downloadFailedInternet.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحميل التفسير. يرجى التأكد من اتصالك بالإنترنت.'**
  String get downloadFailedInternet;

  /// No description provided for @fullTafsirTitle.
  ///
  /// In ar, this message translates to:
  /// **'التفسير الشامل'**
  String get fullTafsirTitle;

  /// No description provided for @translationTitle.
  ///
  /// In ar, this message translates to:
  /// **'الترجمة'**
  String get translationTitle;

  /// No description provided for @bookmarksTitle.
  ///
  /// In ar, this message translates to:
  /// **'العلامات المرجعية'**
  String get bookmarksTitle;

  /// No description provided for @indexTitle.
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get indexTitle;

  /// No description provided for @surahBookmarkTitle.
  ///
  /// In ar, this message translates to:
  /// **'سورة {name}'**
  String surahBookmarkTitle(String name);

  /// No description provided for @verseBookmarkSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الآية {ayah}  •  صفحة {page}'**
  String verseBookmarkSubtitle(String ayah, String page);

  /// No description provided for @goToPageTitle.
  ///
  /// In ar, this message translates to:
  /// **'الذهاب للصفحة {num}'**
  String goToPageTitle(int num);

  /// No description provided for @goToJuzTitle.
  ///
  /// In ar, this message translates to:
  /// **'الذهاب للجزء {name} ({num}) — صفحة {page}'**
  String goToJuzTitle(String name, int num, int page);

  /// No description provided for @goToSurahTitle.
  ///
  /// In ar, this message translates to:
  /// **'الذهاب لسورة {name} ({num}) — صفحة {page}'**
  String goToSurahTitle(String name, int num, int page);

  /// No description provided for @outOfRange.
  ///
  /// In ar, this message translates to:
  /// **'الرقم {num} خارج النطاق المتاح'**
  String outOfRange(String num);

  /// No description provided for @surahListItem.
  ///
  /// In ar, this message translates to:
  /// **'سورة {name}'**
  String surahListItem(String name);

  /// No description provided for @juzListItem.
  ///
  /// In ar, this message translates to:
  /// **'الجزء {name}'**
  String juzListItem(String name);

  /// No description provided for @pageListItem.
  ///
  /// In ar, this message translates to:
  /// **'صفحة {page}'**
  String pageListItem(String page);

  /// No description provided for @surahAndAyah.
  ///
  /// In ar, this message translates to:
  /// **'سورة {surah} - آية {ayah}'**
  String surahAndAyah(String surah, String ayah);

  /// No description provided for @languageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languagePickerTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر اللغة'**
  String get languagePickerTitle;

  /// No description provided for @sleepTimerStopped.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إيقاف التلاوة بعد {minutes} دقائق'**
  String sleepTimerStopped(int minutes);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

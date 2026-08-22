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
  /// **'بحث في الآيات والموضوعات'**
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
  /// **'التفسير'**
  String get menuTafsirTitle;

  /// No description provided for @menuTranslation.
  ///
  /// In ar, this message translates to:
  /// **'الترجمة'**
  String get menuTranslation;

  /// No description provided for @menuWordMeanings.
  ///
  /// In ar, this message translates to:
  /// **'معاني الكلمات'**
  String get menuWordMeanings;

  /// No description provided for @wordMeaningsTitle.
  ///
  /// In ar, this message translates to:
  /// **'معاني الكلمات'**
  String get wordMeaningsTitle;

  /// No description provided for @wordMeaningsPronunciation.
  ///
  /// In ar, this message translates to:
  /// **'النطق الصوتي'**
  String get wordMeaningsPronunciation;

  /// No description provided for @wordMeaningsTranslation.
  ///
  /// In ar, this message translates to:
  /// **'المعنى'**
  String get wordMeaningsTranslation;

  /// No description provided for @menuListen.
  ///
  /// In ar, this message translates to:
  /// **'الاستماع للآيات'**
  String get menuListen;

  /// No description provided for @menuListenOnce.
  ///
  /// In ar, this message translates to:
  /// **'الاستماع لهذه الآية فقط'**
  String get menuListenOnce;

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
  /// **'ابحث عن آية، سورة، جزء، أو صفحة...'**
  String get searchHint;

  /// No description provided for @searchBy.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن طريق'**
  String get searchBy;

  /// No description provided for @searchByHint.
  ///
  /// In ar, this message translates to:
  /// **'النص القرآني • اسم السورة أو رقمها\nرقم الصفحة • رقم الجزء'**
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

  /// No description provided for @audioSpeed.
  ///
  /// In ar, this message translates to:
  /// **'سرعة التلاوة'**
  String get audioSpeed;

  /// No description provided for @themeCream.
  ///
  /// In ar, this message translates to:
  /// **'كريمي'**
  String get themeCream;

  /// No description provided for @themeWhite.
  ///
  /// In ar, this message translates to:
  /// **'أبيض'**
  String get themeWhite;

  /// No description provided for @themeMint.
  ///
  /// In ar, this message translates to:
  /// **'نعناعي'**
  String get themeMint;

  /// No description provided for @themeIceBlue.
  ///
  /// In ar, this message translates to:
  /// **'أزرق ثلجي'**
  String get themeIceBlue;

  /// No description provided for @themeParchment.
  ///
  /// In ar, this message translates to:
  /// **'عتيق'**
  String get themeParchment;

  /// No description provided for @themeRoseGold.
  ///
  /// In ar, this message translates to:
  /// **'روز جولد'**
  String get themeRoseGold;

  /// No description provided for @themeSlate.
  ///
  /// In ar, this message translates to:
  /// **'رخامي'**
  String get themeSlate;

  /// No description provided for @themeOlive.
  ///
  /// In ar, this message translates to:
  /// **'زيتوني'**
  String get themeOlive;

  /// No description provided for @themeEmerald.
  ///
  /// In ar, this message translates to:
  /// **'زمردي'**
  String get themeEmerald;

  /// No description provided for @themeSapphire.
  ///
  /// In ar, this message translates to:
  /// **'كحلي'**
  String get themeSapphire;

  /// No description provided for @themeBurgundy.
  ///
  /// In ar, this message translates to:
  /// **'عنابي'**
  String get themeBurgundy;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'ليلي'**
  String get themeDark;

  /// No description provided for @themeScrollDirection.
  ///
  /// In ar, this message translates to:
  /// **'اتجاه التمرير'**
  String get themeScrollDirection;

  /// No description provided for @themeScrollHorizontal.
  ///
  /// In ar, this message translates to:
  /// **'أفقي'**
  String get themeScrollHorizontal;

  /// No description provided for @themeScrollVertical.
  ///
  /// In ar, this message translates to:
  /// **'رأسي'**
  String get themeScrollVertical;

  /// No description provided for @hifzEnableMode.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل اختبار الحفظ'**
  String get hifzEnableMode;

  /// No description provided for @hifzDisableMode.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف اختبار الحفظ'**
  String get hifzDisableMode;

  /// No description provided for @hifzMaskFull.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الآيات'**
  String get hifzMaskFull;

  /// No description provided for @hifzMaskWord.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الكلمات'**
  String get hifzMaskWord;

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
  /// **'تفسير هذه الآية غير متوفر محليًا'**
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
  /// **'فشل تنزيل التفسير. يرجى التحقق من اتصالك بالإنترنت.'**
  String get downloadFailedInternet;

  /// No description provided for @fullTafsirTitle.
  ///
  /// In ar, this message translates to:
  /// **'التفسير الكامل'**
  String get fullTafsirTitle;

  /// No description provided for @translationTitle.
  ///
  /// In ar, this message translates to:
  /// **'الترجمة الإنجليزية'**
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

  /// No description provided for @themeAppearanceTitle.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get themeAppearanceTitle;

  /// No description provided for @themeAppearanceSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تخصيص ألوان المصحف والوضع الليلي'**
  String get themeAppearanceSubtitle;

  /// No description provided for @themeDarkMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الليلي'**
  String get themeDarkMode;

  /// No description provided for @themeMushafColor.
  ///
  /// In ar, this message translates to:
  /// **'لون المصحف'**
  String get themeMushafColor;

  /// No description provided for @timerCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء المؤقت'**
  String get timerCancelled;

  /// No description provided for @audioErrorFileNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الملف الصوتي غير متوفر.'**
  String get audioErrorFileNotFound;

  /// No description provided for @audioErrorNoInternet.
  ///
  /// In ar, this message translates to:
  /// **'هذه الآيات غير محملة مسبقًا وتتطلب اتصالًا بالإنترنت لتشغيلها.'**
  String get audioErrorNoInternet;

  /// No description provided for @audioErrorPlayback.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تشغيل التلاوة.'**
  String get audioErrorPlayback;

  /// No description provided for @audioErrorPlaylist.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تشغيل القائمة.'**
  String get audioErrorPlaylist;

  /// No description provided for @sleepTimerStopped.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إيقاف التلاوة بعد {minutes} دقائق'**
  String sleepTimerStopped(int minutes);

  /// No description provided for @ok.
  ///
  /// In ar, this message translates to:
  /// **'حسنًا'**
  String get ok;

  /// No description provided for @tafsirAlMuyassar.
  ///
  /// In ar, this message translates to:
  /// **'الميسر'**
  String get tafsirAlMuyassar;

  /// No description provided for @tafsirIbnKathir.
  ///
  /// In ar, this message translates to:
  /// **'ابن كثير'**
  String get tafsirIbnKathir;

  /// No description provided for @tafsirAlSaadi.
  ///
  /// In ar, this message translates to:
  /// **'السعدي'**
  String get tafsirAlSaadi;

  /// No description provided for @tafsirAlTabari.
  ///
  /// In ar, this message translates to:
  /// **'الطبري'**
  String get tafsirAlTabari;

  /// No description provided for @tafsirAlQurtubi.
  ///
  /// In ar, this message translates to:
  /// **'القرطبي'**
  String get tafsirAlQurtubi;

  /// No description provided for @tafsirAlWaseet.
  ///
  /// In ar, this message translates to:
  /// **'الوسيط'**
  String get tafsirAlWaseet;

  /// No description provided for @tafsirAlBaghawi.
  ///
  /// In ar, this message translates to:
  /// **'البغوي'**
  String get tafsirAlBaghawi;

  /// No description provided for @notificationChannelRecitations.
  ///
  /// In ar, this message translates to:
  /// **'تلاوات القرآن'**
  String get notificationChannelRecitations;

  /// No description provided for @tafsirEnIbnKathir.
  ///
  /// In ar, this message translates to:
  /// **'ابن كثير (مختصر)'**
  String get tafsirEnIbnKathir;

  /// No description provided for @tafsirEnAsSaadi.
  ///
  /// In ar, this message translates to:
  /// **'السعدي'**
  String get tafsirEnAsSaadi;

  /// No description provided for @tafsirEnMaarif.
  ///
  /// In ar, this message translates to:
  /// **'معارف القرآن'**
  String get tafsirEnMaarif;

  /// No description provided for @tafsirEnTazkirul.
  ///
  /// In ar, this message translates to:
  /// **'تذكير القرآن'**
  String get tafsirEnTazkirul;

  /// No description provided for @menuShareCard.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الآيات'**
  String get menuShareCard;

  /// No description provided for @verseCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الآيات'**
  String get verseCardTitle;

  /// No description provided for @verseCardShareImage.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة البطاقة'**
  String get verseCardShareImage;

  /// No description provided for @verseCardSaveImage.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الصورة'**
  String get verseCardSaveImage;

  /// No description provided for @verseCardShareText.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة النص'**
  String get verseCardShareText;

  /// No description provided for @verseCardCopyText.
  ///
  /// In ar, this message translates to:
  /// **'نسخ النص'**
  String get verseCardCopyText;

  /// No description provided for @verseCardCopiedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ النص بنجاح'**
  String get verseCardCopiedSuccess;

  /// No description provided for @verseCardFormatLabel.
  ///
  /// In ar, this message translates to:
  /// **'نوع المشاركة'**
  String get verseCardFormatLabel;

  /// No description provided for @verseCardFormatVideo.
  ///
  /// In ar, this message translates to:
  /// **'مقطع فيديو'**
  String get verseCardFormatVideo;

  /// No description provided for @verseCardFormatImage.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة الآيات'**
  String get verseCardFormatImage;

  /// No description provided for @verseCardFormatText.
  ///
  /// In ar, this message translates to:
  /// **'نص قرآني'**
  String get verseCardFormatText;

  /// No description provided for @verseCardFormatFullPage.
  ///
  /// In ar, this message translates to:
  /// **'صفحة كاملة'**
  String get verseCardFormatFullPage;

  /// No description provided for @verseCardShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة البطاقة'**
  String get verseCardShare;

  /// No description provided for @verseCardSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الصورة'**
  String get verseCardSave;

  /// No description provided for @verseCardSavedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ الصورة بنجاح'**
  String get verseCardSavedSuccess;

  /// No description provided for @verseCardIncludeTafsir.
  ///
  /// In ar, this message translates to:
  /// **'إظهار التفسير الميسر'**
  String get verseCardIncludeTafsir;

  /// No description provided for @verseCardIncludeTranslation.
  ///
  /// In ar, this message translates to:
  /// **'إظهار الترجمة الإنجليزية'**
  String get verseCardIncludeTranslation;

  /// No description provided for @verseCardTafsirBadge.
  ///
  /// In ar, this message translates to:
  /// **'التفسير الميسر'**
  String get verseCardTafsirBadge;

  /// No description provided for @verseCardTranslationBadge.
  ///
  /// In ar, this message translates to:
  /// **'الترجمة الإنجليزية'**
  String get verseCardTranslationBadge;

  /// No description provided for @verseCardIncludeBranding.
  ///
  /// In ar, this message translates to:
  /// **'شعار التطبيق'**
  String get verseCardIncludeBranding;

  /// No description provided for @verseCardVerseRange.
  ///
  /// In ar, this message translates to:
  /// **'نطاق الآيات'**
  String get verseCardVerseRange;

  /// No description provided for @verseCardStartAyah.
  ///
  /// In ar, this message translates to:
  /// **'اختر آية البداية'**
  String get verseCardStartAyah;

  /// No description provided for @verseCardEndAyah.
  ///
  /// In ar, this message translates to:
  /// **'اختر آية النهاية'**
  String get verseCardEndAyah;

  /// No description provided for @topicSectionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأقسام والموضوعات القرآنية'**
  String get topicSectionsTitle;

  /// No description provided for @topicSupplications.
  ///
  /// In ar, this message translates to:
  /// **'أدعية القرآن'**
  String get topicSupplications;

  /// No description provided for @topicTaqwa.
  ///
  /// In ar, this message translates to:
  /// **'التقوى والإحسان'**
  String get topicTaqwa;

  /// No description provided for @topicPatience.
  ///
  /// In ar, this message translates to:
  /// **'الصبر والفرج'**
  String get topicPatience;

  /// No description provided for @topicMercy.
  ///
  /// In ar, this message translates to:
  /// **'التبشير والرحمة'**
  String get topicMercy;

  /// No description provided for @topicWarning.
  ///
  /// In ar, this message translates to:
  /// **'الإنذار والوعيد'**
  String get topicWarning;

  /// No description provided for @topicProphets.
  ///
  /// In ar, this message translates to:
  /// **'قصص الأنبياء'**
  String get topicProphets;

  /// No description provided for @topicMorals.
  ///
  /// In ar, this message translates to:
  /// **'الأخلاق والمعاملات'**
  String get topicMorals;

  /// No description provided for @topicCreation.
  ///
  /// In ar, this message translates to:
  /// **'التفكر والخلق'**
  String get topicCreation;

  /// No description provided for @videoStudioTitle.
  ///
  /// In ar, this message translates to:
  /// **'صانع مقاطع القرآن'**
  String get videoStudioTitle;

  /// No description provided for @videoStudioSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تصميم وتصدير مقاطع التلاوات بجودة عالية'**
  String get videoStudioSubtitle;

  /// No description provided for @videoStudioSurahVerses.
  ///
  /// In ar, this message translates to:
  /// **'سورة {surahName} ({startAyah} - {endAyah})'**
  String videoStudioSurahVerses(String surahName, int startAyah, int endAyah);

  /// No description provided for @videoStudioThemeAndBg.
  ///
  /// In ar, this message translates to:
  /// **'المظهر والخلفية'**
  String get videoStudioThemeAndBg;

  /// No description provided for @videoStudioDimensions.
  ///
  /// In ar, this message translates to:
  /// **'أبعاد ومقاس الفيديو'**
  String get videoStudioDimensions;

  /// No description provided for @videoStudioVerseRange.
  ///
  /// In ar, this message translates to:
  /// **'نطاق الآيات'**
  String get videoStudioVerseRange;

  /// No description provided for @videoStudioFromAyah.
  ///
  /// In ar, this message translates to:
  /// **'من آية: {ayah}'**
  String videoStudioFromAyah(int ayah);

  /// No description provided for @videoStudioToAyah.
  ///
  /// In ar, this message translates to:
  /// **'إلى آية: {ayah}'**
  String videoStudioToAyah(int ayah);

  /// No description provided for @videoStudioReciter.
  ///
  /// In ar, this message translates to:
  /// **'القارئ والتلاوة'**
  String get videoStudioReciter;

  /// No description provided for @videoStudioQuality.
  ///
  /// In ar, this message translates to:
  /// **'دقة وجودة الفيديو'**
  String get videoStudioQuality;

  /// No description provided for @videoStudioDisplayOptions.
  ///
  /// In ar, this message translates to:
  /// **'خيارات العرض'**
  String get videoStudioDisplayOptions;

  /// No description provided for @videoStudioShowSurahBadge.
  ///
  /// In ar, this message translates to:
  /// **'إظهار اسم السورة'**
  String get videoStudioShowSurahBadge;

  /// No description provided for @videoStudioShowReciterName.
  ///
  /// In ar, this message translates to:
  /// **'إظهار اسم القارئ'**
  String get videoStudioShowReciterName;

  /// No description provided for @videoStudioShowTafsir.
  ///
  /// In ar, this message translates to:
  /// **'إظهار التفسير الميسر'**
  String get videoStudioShowTafsir;

  /// No description provided for @videoStudioShowTranslation.
  ///
  /// In ar, this message translates to:
  /// **'إظهار الترجمة الإنجليزية'**
  String get videoStudioShowTranslation;

  /// No description provided for @videoStudioShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الفيديو'**
  String get videoStudioShare;

  /// No description provided for @videoStudioSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الفيديو'**
  String get videoStudioSave;

  /// No description provided for @videoStudioFullscreenPreview.
  ///
  /// In ar, this message translates to:
  /// **'معاينة بملء الشاشة'**
  String get videoStudioFullscreenPreview;

  /// No description provided for @videoStudioProgressTitle.
  ///
  /// In ar, this message translates to:
  /// **'جاري إعداد مقطع الفيديو'**
  String get videoStudioProgressTitle;

  /// No description provided for @videoStudioProgressCompleted.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء مقطع الفيديو بنجاح'**
  String get videoStudioProgressCompleted;

  /// No description provided for @videoStudioProgressFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر إعداد مقطع الفيديو'**
  String get videoStudioProgressFailed;

  /// No description provided for @videoStudioCancelExport.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإعداد'**
  String get videoStudioCancelExport;

  /// No description provided for @videoStudioClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get videoStudioClose;

  /// No description provided for @videoStudioAyahOf.
  ///
  /// In ar, this message translates to:
  /// **'الآية {current} من {total}'**
  String videoStudioAyahOf(int current, int total);

  /// No description provided for @videoStudioAyahOfSurah.
  ///
  /// In ar, this message translates to:
  /// **'الآية {current} من {total} (سورة {surahName})'**
  String videoStudioAyahOfSurah(int current, int total, String surahName);

  /// No description provided for @videoStudioSavedSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ مقطع الفيديو في معرض الهاتف بنجاح'**
  String get videoStudioSavedSuccess;

  /// No description provided for @videoStudioSavedError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر حفظ الفيديو في المعرض'**
  String get videoStudioSavedError;

  /// No description provided for @videoStudioAudioLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل التلاوة الصوتية للقارئ المحدد'**
  String get videoStudioAudioLoadError;

  /// No description provided for @videoStudioShareCaption.
  ///
  /// In ar, this message translates to:
  /// **'تلاوة عطرة من تطبيق تبتل'**
  String get videoStudioShareCaption;

  /// No description provided for @videoStudioChooseReciter.
  ///
  /// In ar, this message translates to:
  /// **'اختر القارئ'**
  String get videoStudioChooseReciter;

  /// No description provided for @videoStudioAllReciters.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get videoStudioAllReciters;

  /// No description provided for @videoStudioViewAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get videoStudioViewAll;

  /// No description provided for @videoThemeCream.
  ///
  /// In ar, this message translates to:
  /// **'كريمي'**
  String get videoThemeCream;

  /// No description provided for @videoThemeWhite.
  ///
  /// In ar, this message translates to:
  /// **'أبيض'**
  String get videoThemeWhite;

  /// No description provided for @videoThemeVintage.
  ///
  /// In ar, this message translates to:
  /// **'عتيق'**
  String get videoThemeVintage;

  /// No description provided for @videoThemeRoseGold.
  ///
  /// In ar, this message translates to:
  /// **'روز جولد'**
  String get videoThemeRoseGold;

  /// No description provided for @videoThemeEmerald.
  ///
  /// In ar, this message translates to:
  /// **'زمردي'**
  String get videoThemeEmerald;

  /// No description provided for @videoThemeMidnight.
  ///
  /// In ar, this message translates to:
  /// **'كحلي ليلي'**
  String get videoThemeMidnight;

  /// No description provided for @videoThemeRoyalDark.
  ///
  /// In ar, this message translates to:
  /// **'ملكي داكن'**
  String get videoThemeRoyalDark;

  /// No description provided for @videoRatioStory.
  ///
  /// In ar, this message translates to:
  /// **'قصة (9:16)'**
  String get videoRatioStory;

  /// No description provided for @videoRatioSquare.
  ///
  /// In ar, this message translates to:
  /// **'مربع (1:1)'**
  String get videoRatioSquare;

  /// No description provided for @videoRatioLandscape.
  ///
  /// In ar, this message translates to:
  /// **'عرضي (16:9)'**
  String get videoRatioLandscape;

  /// No description provided for @videoQuality4K.
  ///
  /// In ar, this message translates to:
  /// **'فائقة (4K)'**
  String get videoQuality4K;

  /// No description provided for @videoQuality1080p.
  ///
  /// In ar, this message translates to:
  /// **'عالية (1080p)'**
  String get videoQuality1080p;

  /// No description provided for @videoQuality720p.
  ///
  /// In ar, this message translates to:
  /// **'سريعة (720p)'**
  String get videoQuality720p;

  /// No description provided for @videoQualityFast.
  ///
  /// In ar, this message translates to:
  /// **'سريعة'**
  String get videoQualityFast;

  /// No description provided for @videoQualityHigh.
  ///
  /// In ar, this message translates to:
  /// **'عالية الدقة'**
  String get videoQualityHigh;

  /// No description provided for @videoQualityUltra.
  ///
  /// In ar, this message translates to:
  /// **'فائقة'**
  String get videoQualityUltra;
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

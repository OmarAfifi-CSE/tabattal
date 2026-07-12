// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Tabattal';

  @override
  String get drawerSearch => 'Advanced Search';

  @override
  String get drawerSearchSubtitle => 'Search by text or numbers';

  @override
  String get drawerIndex => 'Index';

  @override
  String get drawerIndexSubtitle => 'Surahs & Juzs';

  @override
  String get drawerBookmarks => 'Bookmarks';

  @override
  String get drawerBookmarksSubtitle => 'Saved verses';

  @override
  String get drawerTafsir => 'Full Tafsir';

  @override
  String get drawerTafsirSubtitle => 'Commentary on all verses and surahs';

  @override
  String get drawerTranslation => 'English Translation';

  @override
  String get drawerTranslationSubtitle => 'Meanings of the Quran';

  @override
  String get drawerAudioManager => 'Audio Manager';

  @override
  String get drawerAudioManagerSubtitle => 'Download & manage recitations';

  @override
  String get drawerLanguage => 'Language';

  @override
  String get drawerLanguageSubtitle => 'العربية / English';

  @override
  String get menuTafsir => 'Tafsir';

  @override
  String get menuTafsirTitle => 'Tafsir - Al-Muyassar';

  @override
  String get menuTranslation => 'Translation';

  @override
  String get menuListen => 'Listen to Verses';

  @override
  String get menuGoToVerse => 'Go to Playing Verse';

  @override
  String get menuBookmarkAdd => 'Add Bookmark';

  @override
  String get menuBookmarkRemove => 'Remove Bookmark';

  @override
  String get retry => 'Retry';

  @override
  String get noBookmarks => 'No Bookmarks';

  @override
  String get noBookmarksHint => 'Tap any verse to bookmark it';

  @override
  String get noResults => 'No results found';

  @override
  String get searchHint => 'Search by text or number...';

  @override
  String get searchBy => 'Search by';

  @override
  String get searchByHint =>
      'Page number • Juz number • Surah number\nor Quranic text';

  @override
  String get pagePrefix => 'Page';

  @override
  String get surahPrefix => 'Surah';

  @override
  String get juzPrefix => 'Juz';

  @override
  String get ayahPrefix => 'Verse';

  @override
  String get audioSpeed => 'سرعة التلاوة';

  @override
  String get themeCream => 'Creamy';

  @override
  String get themeWhite => 'White';

  @override
  String get themeMint => 'Mint';

  @override
  String get themeIceBlue => 'Ice Blue';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeScrollDirection => 'Scroll Direction';

  @override
  String get themeScrollHorizontal => 'Horizontal';

  @override
  String get themeScrollVertical => 'Vertical';

  @override
  String get audioTypeLabel => 'Type';

  @override
  String get audioReciterLabel => 'Reciter';

  @override
  String get audioRepeatLabel => 'Repeat verse';

  @override
  String get audioRepeatContinuous => 'Continuous repeat';

  @override
  String get audioRepeatNone => 'No repeat (continue)';

  @override
  String get audioRepeatTwice => 'Repeat twice';

  @override
  String get audioRepeatThrice => 'Repeat three times';

  @override
  String get audioStartListening => 'Start Listening';

  @override
  String get audioSaveSettings => 'Save Settings';

  @override
  String get audioSettingsTitle => 'Listening Settings';

  @override
  String get audioDownloadAll => 'Download Full Quran';

  @override
  String get audioManagerTitle => 'Audio Manager';

  @override
  String get timerStop => 'Stop Timer';

  @override
  String get timerMinutes5 => '5 minutes';

  @override
  String get timerMinutes10 => '10 minutes';

  @override
  String get timerMinutes15 => '15 minutes';

  @override
  String get timerMinutes30 => '30 minutes';

  @override
  String get timerMinutes60 => '60 minutes';

  @override
  String get indexSurahsTab => 'Surahs';

  @override
  String get indexJuzsTab => 'Juzs';

  @override
  String downloadingTafsir(int percent) {
    return 'Downloading Tafsir... $percent%';
  }

  @override
  String get downloadingTafsirBackground =>
      'Downloading remaining Tafsir in background...';

  @override
  String get tafsirNotAvailableLocally =>
      'Tafsir for this verse is not available locally';

  @override
  String tafsirPartialDownloadHint(int percent) {
    return '$percent% of Tafsir downloaded. Continue download?';
  }

  @override
  String get continueDownload => 'Continue Download';

  @override
  String get noLocalData => 'No data in local database';

  @override
  String get noLocalTranslation => 'No translation in local database';

  @override
  String get noTafsirAvailable => 'No tafsir available';

  @override
  String get indexLoadError => 'Failed to load index';

  @override
  String downloadFailed(String name) {
    return 'Download failed: $name';
  }

  @override
  String get downloadFailedInternet =>
      'Failed to download Tafsir. Please check your internet connection.';

  @override
  String get fullTafsirTitle => 'Full Tafsir';

  @override
  String get translationTitle => 'Translation';

  @override
  String get bookmarksTitle => 'Bookmarks';

  @override
  String get indexTitle => 'Index';

  @override
  String surahBookmarkTitle(String name) {
    return 'Surah $name';
  }

  @override
  String verseBookmarkSubtitle(String ayah, String page) {
    return 'Verse $ayah  •  Page $page';
  }

  @override
  String goToPageTitle(int num) {
    return 'Go to Page $num';
  }

  @override
  String goToJuzTitle(String name, int num, int page) {
    return 'Go to Juz $name ($num) — Page $page';
  }

  @override
  String goToSurahTitle(String name, int num, int page) {
    return 'Go to Surah $name ($num) — Page $page';
  }

  @override
  String outOfRange(String num) {
    return 'Number $num is out of range';
  }

  @override
  String surahListItem(String name) {
    return 'Surah $name';
  }

  @override
  String juzListItem(String name) {
    return 'Juz\' $name';
  }

  @override
  String pageListItem(String page) {
    return 'Page $page';
  }

  @override
  String surahAndAyah(String surah, String ayah) {
    return 'Surah $surah — Verse $ayah';
  }

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePickerTitle => 'Choose Language';

  @override
  String get themeAppearanceTitle => 'Appearance';

  @override
  String get themeAppearanceSubtitle => 'Customize Mushaf colors and dark mode';

  @override
  String get themeDarkMode => 'Dark Mode';

  @override
  String get themeMushafColor => 'Mushaf Color';

  @override
  String get timerCancelled => 'Timer cancelled';

  @override
  String get audioErrorFileNotFound => 'Audio file not available.';

  @override
  String get audioErrorPlayback => 'Error playing audio.';

  @override
  String get audioErrorPlaylist => 'Error playing playlist.';

  @override
  String sleepTimerStopped(int minutes) {
    return 'Recitation will stop in $minutes minutes';
  }
}

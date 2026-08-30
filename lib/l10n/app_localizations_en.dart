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
  String get drawerSearchSubtitle => 'Search in verses & topics';

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
  String get drawerThemeAndLanguage => 'Appearance & Language';

  @override
  String get drawerThemeAndLanguageSubtitle =>
      'Customize Mushaf & Dark Mode • العربية / English';

  @override
  String get themeAndLanguageTitle => 'Appearance & Language';

  @override
  String get menuTafsir => 'Tafsir';

  @override
  String get menuTafsirTitle => 'Tafsir';

  @override
  String get menuTranslation => 'Translation';

  @override
  String get menuWordMeanings => 'Word Meanings';

  @override
  String get wordMeaningsTitle => 'Word Meanings';

  @override
  String get wordMeaningsPronunciation => 'Pronunciation';

  @override
  String get wordMeaningsTranslation => 'Meaning';

  @override
  String get menuListen => 'Listen to Verses';

  @override
  String get menuListenOnce => 'Listen to this Verse only';

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
  String get searchHint => 'Search verse, surah, juz, or page...';

  @override
  String get searchBy => 'Search by';

  @override
  String get searchByHint =>
      'Quranic text • Surah name or number\nPage number • Juz number';

  @override
  String get pagePrefix => 'Page';

  @override
  String get surahPrefix => 'Surah';

  @override
  String get juzPrefix => 'Juz';

  @override
  String get ayahPrefix => 'Verse';

  @override
  String get audioSpeed => 'Speed';

  @override
  String get themeCream => 'Creamy';

  @override
  String get themeWhite => 'White';

  @override
  String get themeMint => 'Mint';

  @override
  String get themeIceBlue => 'Ice Blue';

  @override
  String get themeParchment => 'Parchment';

  @override
  String get themeRoseGold => 'Rose Gold';

  @override
  String get themeSlate => 'Slate Marble';

  @override
  String get themeOlive => 'Warm Olive';

  @override
  String get themeEmerald => 'Emerald';

  @override
  String get themeSapphire => 'Sapphire';

  @override
  String get themeBurgundy => 'Burgundy';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeScrollDirection => 'Scroll Direction';

  @override
  String get themeScrollHorizontal => 'Horizontal';

  @override
  String get themeScrollVertical => 'Vertical';

  @override
  String get hifzEnableMode => 'Memorization Test';

  @override
  String get hifzDisableMode => 'Exit Memorization Test';

  @override
  String get hifzMaskFull => 'Hide Verses';

  @override
  String get hifzMaskWord => 'Hide Words';

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
  String get audioErrorNoInternet =>
      'These ayahs are not downloaded and require an internet connection to stream.';

  @override
  String get audioErrorPlayback => 'Error playing audio.';

  @override
  String get audioErrorPlaylist => 'Error playing playlist.';

  @override
  String sleepTimerStopped(int minutes) {
    return 'Recitation will stop in $minutes minutes';
  }

  @override
  String get ok => 'OK';

  @override
  String get tafsirAlMuyassar => 'Al-Muyassar';

  @override
  String get tafsirIbnKathir => 'Ibn Kathir';

  @override
  String get tafsirAlSaadi => 'Al-Saadi';

  @override
  String get tafsirAlTabari => 'Al-Tabari';

  @override
  String get tafsirAlQurtubi => 'Al-Qurtubi';

  @override
  String get tafsirAlWaseet => 'Al-Waseet';

  @override
  String get tafsirAlBaghawi => 'Al-Baghawi';

  @override
  String get notificationChannelRecitations => 'Quran Recitations';

  @override
  String get tafsirEnIbnKathir => 'Ibn Kathir (Abridged)';

  @override
  String get tafsirEnAsSaadi => 'As-Sa\'di';

  @override
  String get tafsirEnMaarif => 'Ma\'arif-ul-Quran';

  @override
  String get tafsirEnTazkirul => 'Tazkirul Quran';

  @override
  String get menuShareCard => 'Share Verses';

  @override
  String get verseCardTitle => 'Share Verses';

  @override
  String get verseCardTitleImage => 'Verse Card Designer';

  @override
  String get verseCardTitleText => 'Share Text';

  @override
  String get verseCardTitleFullPage => 'Share Mushaf Page';

  @override
  String get verseCardShareImage => 'Share Card';

  @override
  String get verseCardSaveImage => 'Save Image';

  @override
  String get verseCardShareText => 'Share Text';

  @override
  String get verseCardCopyText => 'Copy Text';

  @override
  String get verseCardCopiedSuccess => 'Text copied successfully';

  @override
  String get verseCardFormatLabel => 'Share Format';

  @override
  String get verseCardFormatVideo => 'Quran Video';

  @override
  String get verseCardFormatImage => 'Verse Card';

  @override
  String get verseCardFormatText => 'Plain Text';

  @override
  String get verseCardFormatFullPage => 'Full Page';

  @override
  String get verseCardShare => 'Share Card';

  @override
  String get verseCardSave => 'Save Image';

  @override
  String get verseCardSavedSuccess => 'Image saved successfully';

  @override
  String get verseCardIncludeTafsir => 'Show Tafsir (Al-Muyassar)';

  @override
  String get verseCardIncludeTranslation => 'Show English Translation';

  @override
  String get verseCardTafsirBadge => 'Al-Muyassar Tafsir';

  @override
  String get verseCardTranslationBadge => 'English Translation';

  @override
  String get verseCardIncludeBranding => 'App Logo';

  @override
  String get verseCardVerseRange => 'Verse Range';

  @override
  String get verseCardStartAyah => 'Select Start Ayah';

  @override
  String get verseCardEndAyah => 'Select End Ayah';

  @override
  String get topicSectionsTitle => 'Quranic Topics & Categories';

  @override
  String get topicSupplications => 'Quranic Duas';

  @override
  String get topicTaqwa => 'Taqwa & Goodness';

  @override
  String get topicPatience => 'Patience & Relief';

  @override
  String get topicMercy => 'Mercy & Hope';

  @override
  String get topicWarning => 'Warning & Reminders';

  @override
  String get topicProphets => 'Prophets Stories';

  @override
  String get topicMorals => 'Morals & Ethics';

  @override
  String get topicCreation => 'Creation & Universe';

  @override
  String get videoStudioTitle => 'Quran Video Maker';

  @override
  String get videoStudioSubtitle => 'Create and export recitation video clips';

  @override
  String videoStudioSurahVerses(String surahName, int startAyah, int endAyah) {
    return 'Surah $surahName ($startAyah - $endAyah)';
  }

  @override
  String get videoStudioThemeAndBg => 'Theme & Background';

  @override
  String get videoStudioDimensions => 'Video Dimensions & Quality';

  @override
  String get videoStudioVerseRange => 'Verse Range';

  @override
  String videoStudioFromAyah(int ayah) {
    return 'From Ayah: $ayah';
  }

  @override
  String videoStudioToAyah(int ayah) {
    return 'To Ayah: $ayah';
  }

  @override
  String get videoStudioReciter => 'Reciter & Recitation';

  @override
  String get videoStudioQuality => 'Video Quality';

  @override
  String get videoStudioDisplayOptions => 'Display Options';

  @override
  String get videoStudioShowSurahBadge => 'Show Surah Name';

  @override
  String get videoStudioShowReciterName => 'Show Reciter Name';

  @override
  String get videoStudioShowCardFrame => 'Show Card Frame';

  @override
  String get videoStudioShowTafsir => 'Show Tafsir (Al-Muyassar)';

  @override
  String get videoStudioShowTranslation => 'Show English Translation';

  @override
  String get videoStudioShare => 'Share Video';

  @override
  String get videoStudioSave => 'Save Video';

  @override
  String get videoStudioFullscreenPreview => 'Fullscreen Preview';

  @override
  String get videoStudioProgressTitle => 'Preparing Quran Video';

  @override
  String get videoStudioProgressCompleted => 'Video created successfully';

  @override
  String get videoStudioProgressFailed => 'Failed to create video';

  @override
  String get videoStudioCancelExport => 'Cancel';

  @override
  String get videoStudioClose => 'Close';

  @override
  String videoStudioAyahOf(int current, int total) {
    return 'Ayah $current of $total';
  }

  @override
  String videoStudioAyahOfSurah(int current, int total, String surahName) {
    return 'Ayah $current of $total (Surah $surahName)';
  }

  @override
  String get videoStudioSavedSuccess => 'Video saved to gallery successfully';

  @override
  String get videoStudioSavedError => 'Failed to save video to gallery';

  @override
  String get videoStudioAudioLoadError =>
      'Could not load audio recitation for selected reciter';

  @override
  String get videoStudioShareCaption => 'Blessed recitation from Tabattal app';

  @override
  String get videoStudioChooseReciter => 'Select Reciter';

  @override
  String get videoStudioAllReciters => 'All';

  @override
  String get videoStudioViewAll => 'View All';

  @override
  String get videoThemeCream => 'Cream';

  @override
  String get videoThemeWhite => 'White';

  @override
  String get videoThemeVintage => 'Vintage';

  @override
  String get videoThemeRoseGold => 'Rose Gold';

  @override
  String get videoThemeEmerald => 'Emerald';

  @override
  String get videoThemeMidnight => 'Midnight';

  @override
  String get videoThemeRoyalDark => 'Royal Dark';

  @override
  String get videoRatioStory => 'Story (9:16)';

  @override
  String get videoRatioSquare => 'Square (1:1)';

  @override
  String get videoRatioLandscape => 'Landscape (16:9)';

  @override
  String get videoQuality1080p => '1080p Full HD';

  @override
  String get videoQuality720p => '720p HD';

  @override
  String get videoQualityFast => 'Fast';

  @override
  String get videoQualityHigh => 'Full HD';

  @override
  String get videoStudioDisplayMode => 'Text Display Mode';

  @override
  String get videoDisplayModeLineByLine => 'Line by Line';

  @override
  String get videoDisplayModeStaticFull => 'Full Ayah';

  @override
  String get videoBgCustomVideo => 'Custom Video';

  @override
  String get videoBgChooseVideoGallery => 'Choose from Gallery';

  @override
  String get videoBgChooseVideoGallerySub =>
      'Pick a video from your device as an animated background';

  @override
  String get videoBgVideoUrl => 'Direct Video URL';

  @override
  String get videoBgVideoUrlSub =>
      'Paste a direct video link from the web (MP4)';

  @override
  String get videoBgRemoveVideo => 'Remove Custom Video';

  @override
  String get videoBgCustomVideoActive => 'Custom Video Active';

  @override
  String get videoBgLoadingVideo => 'Processing video...';

  @override
  String get videoBgInvalidVideoUrl => 'Please enter a valid video link (MP4)';

  @override
  String get videoBgCardDesign => 'Card Design';

  @override
  String get videoBgCustomPhoto => 'Custom Photo';

  @override
  String get videoBgChangeVideo => 'Change Video';

  @override
  String get videoStudioDownloadVideo => 'Download Video';

  @override
  String get videoStudioDownloadedSuccess => 'Video downloaded successfully';

  @override
  String get videoStudioDownloadedError => 'Failed to download video';

  @override
  String get videoStudioAudioWaveform => 'Show Audio Waveform';

  @override
  String get videoStudioReplayFromStart => 'Replay from start';

  @override
  String get videoStudioShowSurahBadgeAndAyah =>
      'Show Surah Name & Ayah Number';

  @override
  String get videoStudioThemeAndColors => 'Theme & Colors';

  @override
  String get videoStudioCustomPhotoActive => 'Custom Photo Active';

  @override
  String get videoStudioCustomPhotoTitle => 'Custom Background';

  @override
  String get videoStudioChooseImageGallery => 'Choose from Gallery';

  @override
  String get videoStudioChooseImageGallerySub =>
      'Pick any image from your device as background';

  @override
  String get videoStudioImageUrl => 'Direct Image URL';

  @override
  String get videoStudioImageUrlSub => 'Paste a direct image link from the web';

  @override
  String get videoStudioApplyImage => 'Apply Image';

  @override
  String get videoStudioApplyVideo => 'Apply Video';

  @override
  String get videoStudioRemoveCustomImage => 'Remove Custom Image';

  @override
  String get videoStudioLoadingImage => 'Processing image...';

  @override
  String get videoStudioEnterImageUrl => 'Please enter image URL';

  @override
  String get videoStudioEnterVideoUrl => 'Please enter video URL';

  @override
  String get videoStudioFailedToLoadImage => 'Failed to load image from link';

  @override
  String get videoStudioFailedToLoadVideo => 'Failed to load video from link';

  @override
  String videoStudioPickImageError(String error) {
    return 'Error while picking image: $error';
  }

  @override
  String videoStudioPickVideoError(String error) {
    return 'Error while picking video: $error';
  }

  @override
  String verseCardShareError(String error) {
    return 'Error while sharing: $error';
  }

  @override
  String verseCardSaveError(String error) {
    return 'Error while saving image: $error';
  }

  @override
  String get verseCardImageDownloadedSuccess => 'Image downloaded successfully';

  @override
  String get verseCardImageDownloadedError => 'Error while downloading image';

  @override
  String get verseCardImageSavedGallerySuccess =>
      'Image saved to gallery successfully';

  @override
  String get verseCardImageSavedGalleryError =>
      'Failed to save image to gallery';

  @override
  String get verseCardCapturePageError => 'Failed to capture mushaf page';

  @override
  String get verseCardRetry => 'Retry';

  @override
  String get videoStudioReciterCategoryMurattal => 'Murattal';

  @override
  String get videoStudioReciterCategoryMujawwad => 'Mujawwad';

  @override
  String get verseCardThemeWhite => 'White';

  @override
  String get verseCardThemeParchment => 'Parchment';

  @override
  String get verseCardThemeRoseGold => 'Rose Gold';

  @override
  String get verseCardThemeMint => 'Mint';

  @override
  String get verseCardThemeOlive => 'Olive';

  @override
  String get verseCardThemeIceBlue => 'Ice Blue';

  @override
  String get verseCardThemeSlate => 'Slate';

  @override
  String get verseCardThemeEmerald => 'Emerald';

  @override
  String get verseCardThemeBurgundy => 'Burgundy';

  @override
  String get verseCardThemeDark => 'Night';

  @override
  String get verseCardThemeCream => 'Cream';

  @override
  String get videoExportErrorConnection =>
      'Could not connect to video export server. Please ensure the server is running or check your connection.';

  @override
  String verseCardSurahSingleAyah(String surahName, String ayah) {
    return 'Surah $surahName • Ayah $ayah';
  }

  @override
  String verseCardSurahMultipleAyahs(
    String surahName,
    String startAyah,
    String endAyah,
  ) {
    return 'Surah $surahName • Ayahs ($startAyah - $endAyah)';
  }

  @override
  String verseCardFromAyah(String ayah) {
    return 'From Ayah $ayah';
  }

  @override
  String verseCardToAyah(String ayah) {
    return 'To Ayah $ayah';
  }

  @override
  String verseCardAyah(String ayah) {
    return 'Ayah $ayah';
  }

  @override
  String verseCardSurah(String surahName) {
    return 'Surah $surahName';
  }

  @override
  String get videoStudioProgressDownloadingAudio =>
      'Downloading recitation audio...';

  @override
  String get videoStudioExportPreparing => 'Starting video generation...';

  @override
  String videoStudioProgressReadingTimings(int ayah) {
    return 'Reading word timings for Ayah ($ayah)...';
  }

  @override
  String get videoStudioProgressCreatingBaseFrame =>
      'Creating static base card frame...';

  @override
  String videoStudioProgressRenderingLine(
    int currentLine,
    int totalLines,
    int ayah,
  ) {
    return 'Rendering line ($currentLine of $totalLines) for Ayah ($ayah)...';
  }

  @override
  String videoStudioProgressRenderingVerse(int ayah) {
    return 'Rendering Ayah ($ayah)...';
  }

  @override
  String videoStudioProgressUploadingPayload(int percent) {
    return 'Uploading video data ($percent%)...';
  }

  @override
  String get videoStudioProgressServerMuxing =>
      'Processing and rendering video...';

  @override
  String get videoStudioProgressPreparingDownload =>
      'Preparing video file for download...';

  @override
  String get videoStudioProgressConcatenating =>
      'Muxing and saving final video file...';

  @override
  String get audioDownloadPause => 'Pause Download';

  @override
  String get audioDownloadPaused => 'Download paused';

  @override
  String get audioDownloadStartingAll => 'Starting download for all surahs...';

  @override
  String get audioDownloadAllSuccess => 'All surahs downloaded successfully';

  @override
  String audioDownloadFailedCount(int count) {
    return 'Failed to download $count surahs';
  }

  @override
  String videoStudioProgressPreparingAyahScenes(int current, int total) {
    return 'Preparing scenes for Ayah ($current of $total)...';
  }

  @override
  String videoStudioEncodingProgress(String rendered, String total) {
    return '$rendered / $total';
  }

  @override
  String videoStudioEtaFewSeconds(int seconds) {
    return 'approx. ${seconds}s remaining to complete processing';
  }

  @override
  String videoStudioEtaManySeconds(int seconds) {
    return 'approx. ${seconds}s remaining to complete processing';
  }

  @override
  String get videoStudioEtaOneSecond =>
      'approx. 1 second remaining to complete processing';

  @override
  String get videoStudioEtaTwoSeconds =>
      'approx. 2 seconds remaining to complete processing';

  @override
  String get videoStudioEtaMoments =>
      'just a moment remaining to complete processing...';

  @override
  String videoStudioStartingEncoding(String quality) {
    return 'Starting video processing in $quality...';
  }

  @override
  String videoStudioMeasureDurationError(int ayah) {
    return 'Failed to measure exact audio duration for verse $ayah';
  }

  @override
  String get videoStudioCreateBaseFrameError =>
      'Failed to create base card frame';

  @override
  String videoStudioRenderVerseTextError(int ayah) {
    return 'Failed to render text for verse $ayah';
  }

  @override
  String get videoStudioVideoNotFound => 'Final video file not found';

  @override
  String get videoStudioAudioTimelineIncomplete =>
      'Verse durations list is incomplete';

  @override
  String get videoStudioAudioMeasureFailed =>
      'Failed to measure recitation audio file duration';

  @override
  String get searchFilterAll => 'All';
}

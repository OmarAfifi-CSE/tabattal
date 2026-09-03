import 'package:flutter/widgets.dart';
import '../../features/quran_video_studio/domain/entities/video_enums.dart';

class ReciterCatalog {
  const ReciterCatalog._();

  static const String defaultCategory = 'مرتل';
  static const String defaultReciter = 'محمد صديق المنشاوي';
  static const String defaultReciterPath = 'Minshawy_Murattal_128kbps';

  static const Map<String, Map<String, String>> reciterCategories = {
    'مرتل': {
      // 1. الرعيل الأول وكبار القراء (تلاوات هادئة وتجويد متقن)
      'محمد صديق المنشاوي': 'Minshawy_Murattal_128kbps',
      'محمود خليل الحصري': 'Husary_128kbps',
      'عبد الباسط عبد الصمد': 'Abdul_Basit_Murattal_192kbps',
      'محمود علي البنا': 'mahmoud_ali_al_banna_32kbps',
      'محمد محمود الطبلاوي': 'Mohammad_al_Tablaway_128kbps',

      // 2. الجيل الحديث (سريع وتلاوة معاصرة)
      'ماهر المعيقلي': 'MaherAlMuaiqly128kbps',
      'ياسر الدوسري': 'Yasser_Ad-Dussary_128kbps',
      'أحمد العجمي': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      'سعد الغامدي': 'Ghamadi_40kbps',
      'ناصر القطامي': 'Nasser_Alqatami_128kbps',
      'فارس عباد': 'Fares_Abbad_64kbps',
      'أبو بكر الشاطري': 'Abu_Bakr_Ash-Shaatree_128kbps',
      'سعود الشريم': 'Saood_ash-Shuraym_128kbps',
      'عبدالله عواد الجهني': 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
      'خالد القحطاني': 'Khaalid_Abdullaah_al-Qahtaanee_192kbps',
      'هاني الرفاعي': 'Hani_Rifai_192kbps',

      // 3. قراء الحرمين الكلاسيكيين والتلاوات الهادئة المتأنية
      'علي الحذيفي': 'Hudhaify_128kbps',
      'علي جابر': 'Ali_Jaber_64kbps',
      'محمد أيوب': 'Muhammad_Ayyoub_128kbps',
      'إبراهيم الأخضر': 'Ibrahim_Akhdar_32kbps',
      'عبدالله المطرود': 'Abdullah_Matroud_128kbps',
      'محمد جبريل': 'Muhammad_Jibreel_128kbps',
      'عبد الله بصفر': 'Abdullah_Basfar_192kbps',

      // 4. قراء آخرون (تلاوات متنوعة)
      'صلاح بو خاطر': 'Salaah_AbdulRahman_Bukhatir_128kbps',
      'نبيل الرفاعي': 'Nabil_Rifa3i_48kbps',
      'سهل ياسين': 'Sahl_Yassin_128kbps',
      'ياسر سلامة': 'Yaser_Salamah_128kbps',
      'علي حجاج السويسي': 'Ali_Hajjaj_AlSuesy_128kbps',
      'أكرم العلاقمي': 'Akram_AlAlaqimy_128kbps',
      'محمد عبد الكريم': 'Muhammad_AbdulKareem_128kbps',
      'محسن القاسم': 'Muhsin_Al_Qasim_192kbps',
    },
    'مجود': {
      'عبد الباسط عبد الصمد': 'Abdul_Basit_Mujawwad_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Mujawwad_192kbps',
      'محمود خليل الحصري': 'Husary_128kbps_Mujawwad',
    },
    'المصحف المعلم': {
      'محمود خليل الحصري': 'Husary_Muallim_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Teacher_128kbps',
      'أيمن سويد': 'Ayman_Sowaid_64kbps',
    },
    'رواية ورش': {
      'ياسين الجزائري': 'warsh/warsh_yassin_al_jazaery_64kbps',
      'إبراهيم الدوسري': 'warsh/warsh_ibrahim_aldosary_128kbps',
    },
    'الترجمات الصوتية': {
      'إبراهيم ووك (إنجليزي)': 'English/Sahih_Intnl_Ibrahim_Walk_192kbps',
      'عبد الله بصفر وإبراهيم ووك (عربي / إنجليزي)':
          'MultiLanguage/Basfar_Walk_192kbps',
    },
  };

  /// English names for reciter categories
  static const Map<String, String> categoryEnglishNames = {
    'مرتل': 'Murattal',
    'مجود': 'Mujawwad',
    'المصحف المعلم': 'Teacher (Muallim)',
    'رواية ورش': 'Warsh Recitation',
    'الترجمات الصوتية': 'Audio Translations',
  };

  /// English transliterated names for reciters
  static const Map<String, String> reciterEnglishNames = {
    'محمد صديق المنشاوي': 'Mohamed Siddiq Al-Minshawi',
    'محمود خليل الحصري': 'Mahmoud Khalil Al-Husary',
    'عبد الباسط عبد الصمد': 'Abdul Basit Abdul Samad',
    'محمود علي البنا': 'Mahmoud Ali Al-Banna',
    'محمد محمود الطبلاوي': 'Mohammad Al-Tablaway',
    'ماهر المعيقلي': 'Maher Al-Muaiqly',
    'ياسر الدوسري': 'Yasser Al-Dossari',
    'أحمد العجمي': 'Ahmed Al-Ajmy',
    'سعد الغامدي': 'Saad Al-Ghamdi',
    'ناصر القطامي': 'Nasser Al-Qatami',
    'فارس عباد': 'Fares Abbad',
    'أبو بكر الشاطري': 'Abu Bakr Al-Shatri',
    'سعود الشريم': 'Saud Al-Shuraim',
    'عبدالله عواد الجهني': 'Abdullah Awad Al-Juhany',
    'خالد القحطاني': 'Khaled Al-Qahtani',
    'هاني الرفاعي': 'Hani Al-Rifai',
    'علي الحذيفي': 'Ali Al-Hudhaify',
    'علي جابر': 'Ali Jaber',
    'محمد أيوب': 'Muhammad Ayyub',
    'إبراهيم الأخضر': 'Ibrahim Al-Akhdar',
    'عبدالله المطرود': 'Abdullah Al-Matroud',
    'محمد جبريل': 'Muhammad Jibreel',
    'عبد الله بصفر': 'Abdullah Basfar',
    'صلاح بو خاطر': 'Salah Bukhatir',
    'نبيل الرفاعي': 'Nabil Al-Rifai',
    'سهل ياسين': 'Sahl Yassin',
    'ياسر سلامة': 'Yasser Salameh',
    'علي حجاج السويسي': 'Ali Hajjaj Al-Suwaisi',
    'أكرم العلاقمي': 'Akram Al-Alaqimi',
    'محمد عبد الكريم': 'Muhammad Abdul Kareem',
    'محسن القاسم': 'Muhsin Al-Qasim',
    'أيمن سويد': 'Ayman Sowaid',
    'ياسين الجزائري': 'Yassin Al-Jazaery',
    'إبراهيم الدوسري': 'Ibrahim Al-Dossari',
    'إبراهيم ووك (إنجليزي)': 'Ibrahim Walk (English)',
    'عبد الله بصفر وإبراهيم ووك (عربي / إنجليزي)': 'Basfar & Walk (Arabic / English)',
  };

  /// Reciters with 100% verified millisecond-accurate word timing data for Video Studio
  static const Map<String, List<Map<String, String>>> verifiedVideoRecitersByCategory = {
    'مرتل': [
      {
        'name': 'محمد صديق المنشاوي',
        'category': 'مرتل',
        'path': 'Minshawy_Murattal_128kbps',
      },
      {
        'name': 'محمود خليل الحصري',
        'category': 'مرتل',
        'path': 'Husary_128kbps',
      },
      {
        'name': 'عبد الباسط عبد الصمد',
        'category': 'مرتل',
        'path': 'Abdul_Basit_Murattal_192kbps',
      },
      {
        'name': 'أبو بكر الشاطري',
        'category': 'مرتل',
        'path': 'Abu_Bakr_Ash-Shaatree_128kbps',
      },
      {
        'name': 'سعود الشريم',
        'category': 'مرتل',
        'path': 'Saood_ash-Shuraym_128kbps',
      },
      {
        'name': 'هاني الرفاعي',
        'category': 'مرتل',
        'path': 'Hani_Rifai_192kbps',
      },
    ],
    'مجود': [
      {
        'name': 'محمد صديق المنشاوي',
        'category': 'مجود',
        'path': 'Minshawy_Mujawwad_192kbps',
      },
      {
        'name': 'عبد الباسط عبد الصمد',
        'category': 'مجود',
        'path': 'Abdul_Basit_Mujawwad_128kbps',
      },
    ],
  };

  /// Verified high-fidelity reciters for full ayah video mode
  static const Map<String, List<Map<String, String>>> fullAyahVideoRecitersByCategory = {
    'مرتل': [
      {
        'name': 'محمد صديق المنشاوي',
        'category': 'مرتل',
        'path': 'Minshawy_Murattal_128kbps',
      },
      {
        'name': 'محمود خليل الحصري',
        'category': 'مرتل',
        'path': 'Husary_128kbps',
      },
      {
        'name': 'عبد الباسط عبد الصمد',
        'category': 'مرتل',
        'path': 'Abdul_Basit_Murattal_192kbps',
      },
      {
        'name': 'ماهر المعيقلي',
        'category': 'مرتل',
        'path': 'MaherAlMuaiqly128kbps',
      },
      {
        'name': 'ياسر الدوسري',
        'category': 'مرتل',
        'path': 'Yasser_Ad-Dussary_128kbps',
      },
      {
        'name': 'أحمد العجمي',
        'category': 'مرتل',
        'path': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      },
      {
        'name': 'سعد الغامدي',
        'category': 'مرتل',
        'path': 'Ghamadi_40kbps',
      },
      {
        'name': 'ناصر القطامي',
        'category': 'مرتل',
        'path': 'Nasser_Alqatami_128kbps',
      },
      {
        'name': 'فارس عباد',
        'category': 'مرتل',
        'path': 'Fares_Abbad_64kbps',
      },
      {
        'name': 'أبو بكر الشاطري',
        'category': 'مرتل',
        'path': 'Abu_Bakr_Ash-Shaatree_128kbps',
      },
      {
        'name': 'سعود الشريم',
        'category': 'مرتل',
        'path': 'Saood_ash-Shuraym_128kbps',
      },
      {
        'name': 'هاني الرفاعي',
        'category': 'مرتل',
        'path': 'Hani_Rifai_192kbps',
      },
      {
        'name': 'علي الحذيفي',
        'category': 'مرتل',
        'path': 'Hudhaify_128kbps',
      },
      {
        'name': 'محمد أيوب',
        'category': 'مرتل',
        'path': 'Muhammad_Ayyoub_128kbps',
      },
      {
        'name': 'عبدالله عواد الجهني',
        'category': 'مرتل',
        'path': 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
      },
      {
        'name': 'محمود علي البنا',
        'category': 'مرتل',
        'path': 'mahmoud_ali_al_banna_32kbps',
      },
      {
        'name': 'محمد محمود الطبلاوي',
        'category': 'مرتل',
        'path': 'Mohammad_al_Tablaway_128kbps',
      },
      {
        'name': 'خالد القحطاني',
        'category': 'مرتل',
        'path': 'Khaalid_Abdullaah_al-Qahtaanee_192kbps',
      },
      {
        'name': 'علي جابر',
        'category': 'مرتل',
        'path': 'Ali_Jaber_64kbps',
      },
      {
        'name': 'إبراهيم الأخضر',
        'category': 'مرتل',
        'path': 'Ibrahim_Akhdar_32kbps',
      },
      {
        'name': 'عبدالله المطرود',
        'category': 'مرتل',
        'path': 'Abdullah_Matroud_128kbps',
      },
      {
        'name': 'محمد جبريل',
        'category': 'مرتل',
        'path': 'Muhammad_Jibreel_128kbps',
      },
      {
        'name': 'عبد الله بصفر',
        'category': 'مرتل',
        'path': 'Abdullah_Basfar_192kbps',
      },
      {
        'name': 'صلاح بو خاطر',
        'category': 'مرتل',
        'path': 'Salaah_AbdulRahman_Bukhatir_128kbps',
      },
      {
        'name': 'نبيل الرفاعي',
        'category': 'مرتل',
        'path': 'Nabil_Rifa3i_48kbps',
      },
      {
        'name': 'سهل ياسين',
        'category': 'مرتل',
        'path': 'Sahl_Yassin_128kbps',
      },
      {
        'name': 'ياسر سلامة',
        'category': 'مرتل',
        'path': 'Yaser_Salamah_128kbps',
      },
      {
        'name': 'علي حجاج السويسي',
        'category': 'مرتل',
        'path': 'Ali_Hajjaj_AlSuesy_128kbps',
      },
      {
        'name': 'أكرم العلاقمي',
        'category': 'مرتل',
        'path': 'Akram_AlAlaqimy_128kbps',
      },
      {
        'name': 'محمد عبد الكريم',
        'category': 'مرتل',
        'path': 'Muhammad_AbdulKareem_128kbps',
      },
      {
        'name': 'محسن القاسم',
        'category': 'مرتل',
        'path': 'Muhsin_Al_Qasim_192kbps',
      },
    ],
    'مجود': [
      {
        'name': 'محمد صديق المنشاوي',
        'category': 'مجود',
        'path': 'Minshawy_Mujawwad_192kbps',
      },
      {
        'name': 'عبد الباسط عبد الصمد',
        'category': 'مجود',
        'path': 'Abdul_Basit_Mujawwad_128kbps',
      },
      {
        'name': 'محمود خليل الحصري',
        'category': 'مجود',
        'path': 'Husary_128kbps_Mujawwad',
      },
    ],
    'المصحف المعلم': [
      {
        'name': 'محمود خليل الحصري',
        'category': 'المصحف المعلم',
        'path': 'Husary_Muallim_128kbps',
      },
      {
        'name': 'محمد صديق المنشاوي',
        'category': 'المصحف المعلم',
        'path': 'Minshawy_Teacher_128kbps',
      },
      {
        'name': 'أيمن سويد',
        'category': 'المصحف المعلم',
        'path': 'Ayman_Sowaid_64kbps',
      },
    ],
  };

  /// Returns reciters available for the given video text display mode
  static Map<String, List<Map<String, String>>> getVideoRecitersByCategory(VideoTextDisplayMode mode) {
    if (mode == VideoTextDisplayMode.staticFull) {
      return fullAyahVideoRecitersByCategory;
    }
    return verifiedVideoRecitersByCategory;
  }

  /// Checks if the reciter is supported for the given display mode
  static bool isReciterSupportedForMode(String reciterPath, VideoTextDisplayMode mode) {
    final list = getVideoRecitersByCategory(mode);
    for (final reciters in list.values) {
      for (final r in reciters) {
        if (r['path'] == reciterPath) return true;
      }
    }
    return false;
  }

  /// Returns the English name for any reciter
  static String getReciterNameEnglish(String arabicName) {
    if (reciterEnglishNames.containsKey(arabicName)) {
      return reciterEnglishNames[arabicName]!;
    }
    for (final entry in reciterEnglishNames.entries) {
      if (arabicName.contains(entry.key) || entry.key.contains(arabicName)) {
        return entry.value;
      }
    }
    return arabicName;
  }

  /// Returns the English name for any category
  static String getCategoryNameEnglish(String arabicCategory) {
    return categoryEnglishNames[arabicCategory] ?? arabicCategory;
  }

  /// Universal localization helper that localizes either a reciter name or category name by boolean
  static String localizeByLang(bool isEnglish, String arabicNameOrCategory) {
    if (!isEnglish) return arabicNameOrCategory;
    if (categoryEnglishNames.containsKey(arabicNameOrCategory)) {
      return categoryEnglishNames[arabicNameOrCategory]!;
    }
    return getReciterNameEnglish(arabicNameOrCategory);
  }

  /// Universal localization helper using BuildContext
  static String localize(BuildContext context, String arabicNameOrCategory) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return localizeByLang(isEn, arabicNameOrCategory);
  }

  /// Localize category by BuildContext
  static String localizeCategory(BuildContext context, String category) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return isEn ? getCategoryNameEnglish(category) : category;
  }

  /// Localize reciter by BuildContext
  static String localizeReciter(BuildContext context, String reciter) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return isEn ? getReciterNameEnglish(reciter) : reciter;
  }

  /// Returns the flat EveryAyah reciter path from any category
  static String getReciterPath(String categoryName, String reciterName) {
    if (reciterCategories.containsKey(categoryName)) {
      if (reciterCategories[categoryName]!.containsKey(reciterName)) {
        return reciterCategories[categoryName]![reciterName]!;
      }
    }
    return defaultReciterPath;
  }
}

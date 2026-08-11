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
      'أحمد نعينع': 'Ahmed_Neana_128kbps',

      // 2. الجيل الحديث (سريع وتلاوة معاصرة)
      'مشاري العفاسي': 'Alafasy_128kbps',
      'ماهر المعيقلي': 'MaherAlMuaiqly128kbps',
      'ياسر الدوسري': 'Yasser_Ad-Dussary_128kbps',
      'أحمد العجمي': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      'سعد الغامدي': 'Ghamadi_40kbps',
      'ناصر القطامي': 'Nasser_Alqatami_128kbps',
      'فارس عباد': 'Fares_Abbad_64kbps',
      'أبو بكر الشاطري': 'Abu_Bakr_Ash-Shaatree_128kbps',
      'عبد الرحمن السديس': 'Abdurrahmaan_As-Sudais_192kbps',
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
      'صلاح البدير': 'Salah_Al_Budair_128kbps',
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
      'محمد محمود الطبلاوي': 'Mohammad_al_Tablaway_128kbps',
      'مصطفى إسماعيل': 'Mustafa_Ismail_48kbps',
    },
    'المصحف المعلم': {
      'محمود خليل الحصري': 'Husary_Muallim_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Teacher_128kbps',
      'أيمن سويد': 'Ayman_Sowaid_64kbps',
      'خليفة الطنيجي': 'khalefa_al_tunaiji_64kbps',
    },
    'رواية ورش': {
      'ياسين الجزائري': 'warsh/warsh_yassin_al_jazaery_64kbps',
      'عبد الباسط عبد الصمد': 'warsh/warsh_Abdul_Basit_128kbps',
      'إبراهيم الدوسري': 'warsh/warsh_ibrahim_aldosary_128kbps',
    },
    'الترجمات الصوتية': {
      'إبراهيم ووك (إنجليزي)': 'English/Sahih_Intnl_Ibrahim_Walk_192kbps',
      'عبد الله بصفر وإبراهيم ووك (عربي / إنجليزي)':
          'MultiLanguage/Basfar_Walk_192kbps',
    },
  };

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

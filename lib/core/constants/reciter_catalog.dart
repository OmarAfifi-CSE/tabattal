class ReciterCatalog {
  const ReciterCatalog._();

  static const String defaultReciterPath = 'Alafasy_128kbps';

  static const Map<String, Map<String, String>> categories = {
    'مرتل': {
      'محمود خليل الحصري': 'Husary_128kbps',
      'عبد الباسط عبد الصمد': 'Abdul_Basit_Murattal_192kbps',
      'محمد صديق المنشاوي': 'Minshawy_Murattal_128kbps',
      'مشاري العفاسي': 'Alafasy_128kbps',
      'ماهر المعيقلي': 'MaherAlMuaiqly128kbps',
      'ياسر الدوسري': 'Yasser_Ad-Dussary_128kbps',
      'ناصر القطامي': 'Nasser_Alqatami_128kbps',
      'سعود الشريم': 'Saud_Al-Shuraim_128kbps',
      'عبدالرحمن السديس': 'Abdurrahmaan_As-Sudais_192kbps',
      'أحمد العجمي': 'Ahmed_ibn_Ali_Al-Ajamy_128kbps',
      'سعد الغامدي': 'Ghamadi_40kbps',
      'فارس عباد': 'Fares_Abbad_64kbps',
      'أبو بكر الشاطري': 'Abu_Bakr_Ash-Shaatree_128kbps',
    },
    'مجود': {
      'عبد الباسط عبد الصمد': 'Abdul_Basit_Mujawwad_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Mujawwad_192kbps',
      'محمود خليل الحصري': 'Husary_Mujawwad_64kbps',
      'مصطفى إسماعيل': 'Mustafa_Ismail_48kbps',
    },
    'المصحف المعلم': {
      'محمود خليل الحصري': 'Husary_Muallim_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Teacher_128kbps',
      'خليفة الطنيجي': 'Khaalid_Abdullaah_al-Qahtaanee_192kbps',
    },
    'رواية ورش': {
      'محمود خليل الحصري': 'Husary_128kbps',
      'عبد الباسط عبد الصمد': 'Abdul_Basit_Murattal_192kbps',
      'ياسين الجزائري': 'Yaser_Salamah_128kbps',
    },
    'الترجمات الصوتية': {
      'إبراهيم ووك (إنجليزي)': 'English/Sahih_Intnl_Ibrahim_Walk_192kbps',
      'عبد الله بصفر وإبراهيم ووك (عربي / إنجليزي)': 'MultiLanguage/Basfar_Walk_192kbps',
    },
  };

  static String pathFor(String reciterName) {
    for (final category in categories.values) {
      if (category.containsKey(reciterName)) {
        return category[reciterName]!;
      }
    }
    return defaultReciterPath;
  }
}

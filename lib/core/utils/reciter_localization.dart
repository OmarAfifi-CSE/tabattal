import 'package:flutter/widgets.dart';

class ReciterLocalization {
  const ReciterLocalization._();

  static const Map<String, String> _translations = {
    'مرتل': 'Murattal',
    'مجود': 'Mujawwad',
    'المصحف المعلم': 'Teacher (Muallim)',
    'رواية ورش': 'Warsh Recitation',
    'الترجمات الصوتية': 'Audio Translations',
    
    'محمود خليل الحصري': 'Mahmoud Khalil Al-Husary',
    'عبد الباسط عبد الصمد': 'Abdul Basit Abdul Samad',
    'محمد صديق المنشاوي': 'Muhammad Siddiq Al-Minshawi',
    'مشاري العفاسي': 'Mishary Al-Afasy',
    'ماهر المعيقلي': 'Maher Al-Muaiqly',
    'ياسر الدوسري': 'Yasser Al-Dosari',
    'ناصر القطامي': 'Nasser Al-Qatami',
    'سعود الشريم': 'Saud Al-Shuraim',
    'عبدالرحمن السديس': 'Abdul Rahman Al-Sudais',
    'أحمد العجمي': 'Ahmed Al-Ajmi',
    'سعد الغامدي': 'Saad Al-Ghamdi',
    'فارس عباد': 'Fares Abbad',
    'أبو بكر الشاطري': 'Abu Bakr Al-Shatri',
    'مصطفى إسماعيل': 'Mustafa Ismail',
    'خليفة الطنيجي': 'Khalifa Al-Tunaiji',
    'ياسين الجزائري': 'Yassin Al-Jazaery',
    'إبراهيم ووك (إنجليزي)': 'Ibrahim Walk (English)',
    'عبد الله بصفر وإبراهيم ووك (عربي / إنجليزي)': 'Basfar & Walk (Arabic/English)',
  };

  static String localize(BuildContext context, String arabicName) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return localizeByLang(isEn, arabicName);
  }

  static String localizeByLang(bool isEn, String arabicName) {
    if (!isEn) return arabicName;
    return _translations[arabicName] ?? arabicName;
  }
}

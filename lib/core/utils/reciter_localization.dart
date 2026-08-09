import 'package:flutter/widgets.dart';

class ReciterLocalization {
  const ReciterLocalization._();

  static const Map<String, String> _translations = {
    'مرتل': 'Murattal',
    'مجود': 'Mujawwad',
    'المصحف المعلم': 'Teacher (Muallim)',
    'رواية ورش': 'Warsh Recitation',
    'الترجمات الصوتية': 'Audio Translations',

    // 1. الرعيل الأول وكبار القراء
    'محمد صديق المنشاوي': 'Muhammad Siddiq Al-Minshawi',
    'محمود خليل الحصري': 'Mahmoud Khalil Al-Husary',
    'عبد الباسط عبد الصمد': 'Abdul Basit Abdul Samad',
    'محمود علي البنا': 'Mahmoud Ali Al-Banna',
    'أحمد نعينع': 'Ahmed Neana',

    // 2. الجيل الحديث
    'مشاري العفاسي': 'Mishary Al-Afasy',
    'ماهر المعيقلي': 'Maher Al-Muaiqly',
    'ياسر الدوسري': 'Yasser Al-Dosari',
    'أحمد العجمي': 'Ahmed Al-Ajmi',
    'سعد الغامدي': 'Saad Al-Ghamdi',
    'ناصر القطامي': 'Nasser Al-Qatami',
    'فارس عباد': 'Fares Abbad',
    'أبو بكر الشاطري': 'Abu Bakr Al-Shatri',
    'عبد الرحمن السديس': 'Abdul Rahman Al-Sudais',
    'سعود الشريم': 'Saud Al-Shuraim',
    'عبدالله عواد الجهني': 'Abdullah Awad Al-Juhany',
    'خالد القحطاني': 'Khalid Al-Qahtani',
    'هاني الرفاعي': 'Hani Ar-Rifai',

    // 3. قراء الحرمين الكلاسيكيين
    'علي الحذيفي': 'Ali Al-Hudhaifi',
    'علي جابر': 'Ali Jaber',
    'محمد أيوب': 'Muhammad Ayyub',
    'إبراهيم الأخضر': 'Ibrahim Al-Akhdar',
    'عبدالله المطرود': 'Abdullah Al-Matrood',
    'محمد جبريل': 'Muhammad Jibreel',
    'عبد الله بصفر': 'Abdullah Basfar',

    // 4. قراء آخرون
    'صلاح بو خاطر': 'Salah Bukhatir',
    'صلاح البدير': 'Salah Al-Budair',
    'نبيل الرفاعي': 'Nabeel Ar-Rifai',
    'سهل ياسين': 'Sahl Yassin',
    'ياسر سلامة': 'Yasser Salamah',
    'علي حجاج السويسي': 'Ali Hajjaj Al-Souisi',
    'أكرم العلاقمي': 'Akram Al-Alaqimi',
    'محمد عبد الكريم': 'Muhammad Abdul Kareem',
    'محسن القاسم': 'Muhsin Al-Qasim',

    // قراء إضافيين للأنواع الأخرى
    'محمد محمود الطبلاوي': 'Muhammad Mahmoud Al-Tablawi',
    'مصطفى إسماعيل': 'Mustafa Ismail',
    'أيمن سويد': 'Ayman Suwayd',
    'خليفة الطنيجي': 'Khalifa Al-Tunaiji',
    'ياسين الجزائري': 'Yassin Al-Jazaery',
    'إبراهيم الدوسري': 'Ibrahim Al-Dosari',

    // ترجمات صوتية
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

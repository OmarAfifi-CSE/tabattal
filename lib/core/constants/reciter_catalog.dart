import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../features/quran_video_studio/domain/entities/video_enums.dart';

class ReciterCatalog {
  const ReciterCatalog._();

  static const String defaultCategory = 'مرتل';
  static const String defaultReciter = 'محمد صديق المنشاوي';
  static const String defaultReciterPath = 'Minshawy_Murattal_128kbps';

  static const Map<String, Map<String, String>> reciterCategories = {
    'مرتل': {
      // ── حرف الألف ──
      'أبو بكر الشاطري': 'Abu_Bakr_Ash-Shaatree_128kbps',
      'أحمد الحواشي': 'mp3quran_6_128kbps',
      'أحمد السويلم': 'mp3quran_252_128kbps',
      'أحمد خليل شاهين': 'mp3quran_256_128kbps',
      'أحمد ديبان': 'mp3quran_265_128kbps',
      'أحمد صابر': 'mp3quran_8_128kbps',
      'أحمد الطرابلسي': 'mp3quran_201_128kbps',
      'أحمد عامر': 'mp3quran_203_128kbps',
      'أحمد العجمي': 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      'أحمد عيسى المعصراوي': 'mp3quran_289_128kbps',
      'أحمد النفيس': 'mp3quran_259_128kbps',
      'أكرم العلاقمي': 'Akram_AlAlaqimy_128kbps',
      'أنس العمادي': 'mp3quran_314_128kbps',
      'إبراهيم الأخضر': 'Ibrahim_Akhdar_32kbps',
      'إبراهيم الجرمي': 'mp3quran_164_128kbps',
      'إبراهيم العسيري': 'mp3quran_3_128kbps',
      'إدريس أبكر': 'Idrees_Abkar_128kbps',

      // ── حرف الباء ──
      'بدر التركي': 'mp3quran_254_128kbps',
      'بندر بليله': 'Bandar_Balilah_128kbps',
      'بيشه وا قادر الكردي': 'Peshawa_Kurdi_128kbps',

      // ── حرف التاء ──
      'توفيق الصايغ': 'Tawfeeq_AsSayegh_128kbps',

      // ── حرف الجيم ──
      'جمال شاكر عبدالله': 'mp3quran_18_128kbps',
      'جمعان العصيمي': 'mp3quran_181_128kbps',
      'جنيد آدم عبدالله': 'mp3quran_10908_128kbps',

      // ── حرف الحاء ──
      'حاتم فريد الواعر': 'mp3quran_163_128kbps',
      'حسن الدغريري': 'mp3quran_10905_128kbps',

      // ── حرف الخاء ──
      'خالد الجليل': 'Khalid_AlJaleel_128kbps',
      'خالد الزيادي': 'mp3quran_10909_128kbps',
      'خالد عبدالكافي': 'mp3quran_22_128kbps',
      'خالد كريم محمدي': 'mp3quran_295_128kbps',
      'خالد المهنا': 'mp3quran_159_128kbps',
      'خالد القحطاني': 'Khaalid_Abdullaah_al-Qahtaanee_192kbps',

      // ── حرف الدال ──
      'داود حمزة': 'mp3quran_25_128kbps',

      // ── حرف الراء ──
      'رامي الدعيس': 'mp3quran_230_128kbps',
      'رعد محمد الكردي': 'Raad_AlKurdi_128kbps',

      // ── حرف الزاي ──
      'زكي داغستاني': 'mp3quran_33_128kbps',
      'الزين محمد أحمد': 'mp3quran_13_128kbps',

      // ── حرف السين ──
      'سعد الغامدي': 'Ghamadi_40kbps',
      'سعد المقرن': 'mp3quran_257_128kbps',
      'سعود الشريم': 'Saood_ash-Shuraym_128kbps',
      'سلمان الصديق': 'mp3quran_298_128kbps',
      'سهل ياسين': 'Sahl_Yassin_128kbps',
      'سيد أحمد هاشمي': 'mp3quran_294_128kbps',
      'سيد رمضان': 'mp3quran_36_128kbps',

      // ── حرف الشين ──
      'شيرزاد عبدالرحمن طاهر': 'mp3quran_38_128kbps',

      // ── حرف الصاد ──
      'صابر عبدالحكم': 'mp3quran_39_128kbps',
      'صالح الشمراني': 'mp3quran_300_128kbps',
      'صالح الصاهود': 'mp3quran_40_128kbps',
      'صالح القريشي': 'mp3quran_306_128kbps',
      'صالح الهبدان': 'mp3quran_42_128kbps',
      'صلاح البدير': 'Salah_AlBudair_128kbps',
      'صلاح بو خاطر': 'Salaah_AbdulRahman_Bukhatir_128kbps',
      'صلاح الهاشم': 'mp3quran_44_128kbps',

      // ── حرف العين ──
      'عادل الكلباني': 'mp3quran_160_128kbps',
      'عادل ريان': 'mp3quran_48_128kbps',
      'عاصم اللحیدان': 'mp3quran_10922_128kbps',
      'عبد الباسط عبد الصمد': 'Abdul_Basit_Murattal_192kbps',
      'عبد الله بصفر': 'Abdullah_Basfar_192kbps',
      'عبدالإله بن عون': 'mp3quran_136_128kbps',
      'عبدالباري الثبيتي': 'Abdulbari_AlThubaiti_128kbps',
      'عبدالبارئ محمد': 'mp3quran_50_128kbps',
      'عبدالبديع غيلان': 'mp3quran_10915_128kbps',
      'عبدالرحمن العوسي': 'Abdulrahman_AlOssi_128kbps',
      'عبدالرحمن الماجد': 'mp3quran_236_128kbps',
      'عبدالرحمن الشحات': 'mp3quran_302_128kbps',
      'عبدالرحمن بن عبدالرزاق البدر': 'mp3quran_10913_128kbps',
      'عبدالعزيز التركي': 'mp3quran_282_128kbps',
      'عبدالعزيز الزهراني': 'Abdulaziz_AlZahrani_128kbps',
      'عبدالرشيد صوفي': 'mp3quran_258_128kbps',
      'عبدالكريم الحازمي': 'mp3quran_316_128kbps',
      'عبدالله البعيجان': 'Abdullah_AlBaijan_128kbps',
      'عبدالله الخلف': 'mp3quran_244_128kbps',
      'عبدالله القرافي': 'mp3quran_10914_128kbps',
      'عبدالله الكندري': 'mp3quran_202_128kbps',
      'عبدالله المطرود': 'Abdullah_Matroud_128kbps',
      'عبدالله الموسى': 'Abdullah_AlMousa_128kbps',
      'عبدالله خياط': 'mp3quran_61_128kbps',
      'عبدالله عبدل': 'mp3quran_284_128kbps',
      'عبدالله عواد الجهني': 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
      'عبدالله غيلان': 'mp3quran_63_128kbps',
      'عبدالله كامل': 'mp3quran_267_128kbps',
      'عبدالمحسن الحارثي': 'mp3quran_66_128kbps',
      'عبدالهادي أحمد كناكري': 'mp3quran_70_128kbps',
      'عبدالودود حنيف': 'mp3quran_71_128kbps',
      'علي الحذيفي': 'Hudhaify_128kbps',
      'علي جابر': 'Ali_Jaber_64kbps',
      'علي حجاج السويسي': 'Ali_Hajjaj_AlSuesy_128kbps',
      'عليجان قوري حمدان': 'mp3quran_10917_128kbps',
      'عماد زهير حافظ': 'mp3quran_78_128kbps',
      'عمر الدريويز': 'mp3quran_260_128kbps',

      // ── حرف الفاء ──
      'فارس عباد': 'Fares_Abbad_64kbps',
      'فؤاد الخامري': 'mp3quran_293_128kbps',
      'فيصل الهاجري': 'mp3quran_307_128kbps',

      // ── حرف الميم ──
      'ماجد الزامل': 'mp3quran_139_128kbps',
      'مال الله عبدالرحمن الجابر': 'mp3quran_297_128kbps',
      'ماهر المعيقلي': 'MaherAlMuaiqly128kbps',
      'ماهر شخاشيرو': 'mp3quran_149_128kbps',
      'محسن القاسم': 'Muhsin_Al_Qasim_192kbps',
      'محمد أيوب': 'Muhammad_Ayyoub_128kbps',
      'محمد البخيت': 'mp3quran_250_128kbps',
      'محمد برهجي': 'mp3quran_340_128kbps',
      'محمد جبريل': 'Muhammad_Jibreel_128kbps',
      'محمد خليل القارئ': 'mp3quran_229_128kbps',
      'محمد رشاد الشريف': 'mp3quran_198_128kbps',
      'محمد الزبيدي': 'mp3quran_10918_128kbps',
      'محمد صالح عالم شاه': 'mp3quran_110_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Murattal_128kbps',
      'محمد عبد الكريم': 'Muhammad_AbdulKareem_128kbps',
      'محمد عثمان خان': 'mp3quran_206_128kbps',
      'محمد الفقيه': 'mp3quran_10906_128kbps',
      'محمد اللحيدان': 'mp3quran_107_128kbps',
      'محمد المحيسني': 'mp3quran_108_128kbps',
      'محمد محمود الطبلاوي': 'Mohammad_al_Tablaway_128kbps',
      'محمود خليل الحصري': 'Husary_128kbps',
      'محمود الرفاعي': 'mp3quran_165_128kbps',
      'محمود حرفوش': 'mp3quran_10923_128kbps',
      'محمود عبدالحكم': 'mp3quran_277_128kbps',
      'محمود علي البنا': 'mahmoud_ali_al_banna_32kbps',
      'مختار الحاج': 'mp3quran_283_128kbps',
      'مصطفى اللاهوني': 'mp3quran_126_128kbps',
      'مصطفى رعد العزاوي': 'mp3quran_127_128kbps',
      'معيض الحارثي': 'mp3quran_197_128kbps',
      'مفتاح السلطني': 'mp3quran_182_128kbps',
      'منصور السالمي': 'Mansoor_AlSalmi_128kbps',
      'موسى بلال': 'mp3quran_161_128kbps',

      // ── حرف النون ──
      'ناصر العصفور': 'mp3quran_248_128kbps',
      'ناصر القطامي': 'Nasser_Alqatami_128kbps',
      'ناصر الماجد': 'mp3quran_251_128kbps',
      'نبيل الرفاعي': 'Nabil_Rifa3i_48kbps',
      'نذير المالكي': 'mp3quran_271_128kbps',
      'نعمة الحسان': 'mp3quran_88_128kbps',

      // ── حرف الهاء ──
      'هاني الرفاعي': 'Hani_Rifai_192kbps',
      'هاشم أبو دلال': 'mp3quran_292_128kbps',
      'هيثم الدخين': 'Haitham_AlDukhin_128kbps',

      // ── حرف الواو ──
      'وديع اليمني': 'Wadih_AlYamani_128kbps',

      // ── حرف الياء ──
      'ياسر الدوسري': 'Yasser_Ad-Dussary_128kbps',
      'ياسر سلامة': 'Yaser_Salamah_128kbps',
      'ياسر القرشي': 'mp3quran_93_128kbps',
      'يحيى حوا': 'mp3quran_96_128kbps',
      'يوسف بن نوح أحمد': 'mp3quran_193_128kbps',
      'يوسف الشويعي': 'mp3quran_97_128kbps',
      'يوسف العيدروس': 'mp3quran_10904_128kbps',
    },
    'مجود': {
      'عبد الباسط عبد الصمد': 'Abdul_Basit_Mujawwad_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Mujawwad_192kbps',
      'محمود خليل الحصري': 'Husary_128kbps_Mujawwad',
      'محمود علي البنا': 'mp3quran_122_128kbps',
      'مصطفى إسماعيل': 'mp3quran_288_128kbps',
      'ماهر المعيقلي': 'mp3quran_133_128kbps',
    },
    'المصحف المعلم': {
      'محمود خليل الحصري': 'Husary_Muallim_128kbps',
      'محمد صديق المنشاوي': 'Minshawy_Teacher_128kbps',
      'أيمن سويد': 'Ayman_Sowaid_64kbps',
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
    'إدريس أبكر': 'Idrees Abkar',
    'رعد محمد الكردي': 'Raad Al-Kurdi',
    'بندر بليله': 'Bandar Balilah',
    'وديع اليمني': 'Wadih Al-Yamani',
    'عبدالرحمن العوسي': 'Abdulrahman Al-Ossi',
    'منصور السالمي': 'Mansoor Al-Salmi',
    'خالد الجليل': 'Khalid Al-Jaleel',
    'توفيق الصايغ': 'Tawfeeq As-Sayegh',
    'خليفة الطنيجي': 'Khalifah Al-Tunaiji',
    'صلاح البدير': 'Salah Al-Budair',
    'هيثم الدخين': 'Haitham Al-Dukhin',
    'بيشه وا قادر الكردي': 'Peshawa Qadir Al-Kurdi',
    'عبدالباري الثبيتي': 'Abdulbari Al-Thubaiti',
    'عبدالعزيز الزهراني': 'Abdulaziz Al-Zahrani',
    'عبدالله البعيجان': 'Abdullah Al-Baijan',
    'عبدالله الموسى': 'Abdullah Al-Mousa',
    'إبراهيم العسيري': 'Ibrahim Al-Asiri',
    'أحمد الحواشي': 'Ahmad Al-Hawashi',
    'أحمد النفيس': 'Ahmed Al-Nafis',
    'أحمد صابر': 'Ahmad Saber',
    'الزين محمد أحمد': 'Al-Zain Muhammad Ahmad',
    'خالد عبدالكافي': 'Khaled Abdulkafi',
    'داود حمزة': 'Dawood Hamza',
    'زكي داغستاني': 'Zaki Daghistani',
    'شيرزاد عبدالرحمن طاهر': 'Shirzad Abdulrahman Taher',
    'صابر عبدالحكم': 'Saber Abdulhakam',
    'صالح الصاهود': 'Saleh Al-Sahood',
    'صالح الهبدان': 'Saleh Al-Habdan',
    'صلاح الهاشم': 'Salah Al-Hashem',
    'عادل ريان': 'Adel Rayan',
    'عبدالبارئ محمد': 'Abdulbari Mohammad',
    'عبدالعزيز الأحمد': 'Abdulaziz Al-Ahmad',
    'عبدالله خياط': 'Abdullah Khayat',
    'عبدالمحسن الحارثي': 'Abdulmohsen Al-Harthi',
    'عبدالهادي أحمد كناكري': 'Abdulhadi Ahmad Kanakeri',
    'عبدالودود حنيف': 'Abdulwadood Haneef',
    'عبدالولي الأركاني': 'Abdulwali Al-Arkani',
    'عماد زهير حافظ': 'Imad Zuhair Hafiz',
    'نعمة الحسان': 'Neamah Al-Hassan',
    'محمد صالح عالم شاه': 'Muhammad Saleh Shah',
    'ماجد الزامل': 'Majed Al-Zamel',
    'خالد المهنا': 'Khaled Al-Mohanna',
    'جمعان العصيمي': 'Jamaan Al-Osaimi',
    'يوسف بن نوح أحمد': 'Youssef Bin Noah Ahmad',
    'محمد رشاد الشريف': 'Mohammad Rashad Al-Shareef',
    'أحمد الطرابلسي': 'Ahmad Al-Trabulsi',
    'أحمد عامر': 'Ahmad Amer',
    'محمد خليل القارئ': 'Muhammad Khalil Al-Qari',
    'عبدالرحمن الماجد': 'Abdulrahman Al-Majed',
    'عبدالله الخلف': 'Abdullah Al-Khalaf',
    'محمد البخيت': 'Mohammad Al-Bukheit',
    'أحمد خليل شاهين': 'Ahmad Khalil Shaheen',
    'عبدالرشيد صوفي': 'Abdulrasheed Soufi',
    'أحمد ديبان': 'Ahmad Deban',
    'عبدالعزيز التركي': 'Abdulaziz Al-Turki',
    'أحمد عيسى المعصراوي': 'Ahmad Issa Al-Masarawi',
    'سيد أحمد هاشمي': 'Sayed Ahmad Hashemi',
    'خالد كريم محمدي': 'Khaled Karim Mohammadi',
    'صالح الشمراني': 'Saleh Al-Shamrani',
    'عيسى عمر سناكو': 'Issa Omar Sanakou',
    'أنس العمادي': 'Anas Al-Emadi',
    'محمد برهجي': 'Mohammad Barhaji',
    'حسن الدغريري': 'Hasan Al-Daghriri',
    'مصطفى إسماعيل': 'Mustafa Ismail',
    'أيمن سويد': 'Ayman Sowaid',
    'إبراهيم ووك (إنجليزي)': 'Ibrahim Walk (English)',
    'عبد الله بصفر وإبراهيم ووك (عربي / إنجليزي)': 'Basfar & Walk (Arabic / English)',
    'محمد اللحيدان': 'Muhammad Al-Luhaidan',
    'محمد المحيسني': 'Muhammad Al-Muhaisny',
    'مصطفى اللاهوني': 'Mustafa Al-Lahoni',
    'مصطفى رعد العزاوي': 'Mustafa Raad Al-Azzawi',
    'مفتاح السلطني': 'Muftah Al-Sultany',
    'عبدالإله بن عون': 'Abdulelah Bin Aoun',
    'ماهر شخاشيرو': 'Maher Shakhashiro',
    'عادل الكلباني': 'Adel Al-Kalbani',
    'موسى بلال': 'Musa Bilal',
    'حاتم فريد الواعر': 'Hatem Fareed Al-Waer',
    'إبراهيم الجرمي': 'Ibrahim Al-Jormi',
    'محمود الرفاعي': 'Mahmoud Al-Rifai',
    'جمال شاكر عبدالله': 'Jamal Shaker Abdullah',
    'معيض الحارثي': 'Moeed Al-Harthi',
    'عبدالله الكندري': 'Abdullah Al-Kandari',
    'محمد عثمان خان': 'Muhammad Usman Khan',
    'عبدالله القرافي': 'Abdullah Al-Qarafi',
    'عبدالبديع غيلان': 'Abdulbadee Ghailan',
    'يوسف العيدروس': 'Yousef Al-Aydaroos',
    'محمد الفقيه': 'Muhammad Al-Faqih',
    'جنيد آدم عبدالله': 'Junaid Adam Abdullah',
    'خالد الزيادي': 'Khaled Al-Ziyadi',
    'عبدالرحمن بن عبدالرزاق البدر': 'Abdulrahman Al-Badr',
    'عليجان قوري حمدان': 'Alijon Qori Hamdan',
    'محمد الزبيدي': 'Muhammad Al-Zubaidi',
    'عاصم اللحیدان': 'Asim Al-Luhaidan',
    'محمود حرفوش': 'Mahmoud Harfoush',
    'رامي الدعيس': 'Rami Al-Deais',
    'ناصر العصفور': 'Nasser Al-Osfour',
    'ناصر الماجد': 'Nasser Al-Majed',
    'أحمد السويلم': 'Ahmed Al-Suwailem',
    'بدر التركي': 'Bader Al-Turki',
    'سعد المقرن': 'Saad Al-Muqrin',
    'عمر الدريويز': 'Omar Al-Duraiweez',
    'عبدالله كامل': 'Abdullah Kamel',
    'نذير المالكي': 'Natheer Al-Malki',
    'محمود عبدالحكم': 'Mahmoud Abdelhakam',
    'هاشم أبو دلال': 'Hashem Abu Dalal',
    'فؤاد الخامري': 'Fouad Al-Khameri',
    'مال الله عبدالرحمن الجابر': 'Mal-Allah Al-Jaber',
    'سلمان الصديق': 'Salman Al-Sadeeq',
    'عبدالرحمن الشحات': 'Abdulrahman Al-Shahhat',
    'صالح القريشي': 'Saleh Al-Quraishi',
    'فيصل الهاجري': 'Faisal Al-Hajri',
    'عبدالكريم الحازمي': 'Abdulkarim Al-Hazmi',
    'سيد رمضان': 'Sayed Ramadan',
    'مختار الحاج': 'Mukhtar Al-Haj',
    'عبدالله غيلان': 'Abdullah Ghailan',
    'ياسر القرشي': 'Yasser Al-Qurashi',
    'يحيى حوا': 'Yahya Hawwa',
    'يوسف الشويعي': 'Yousef Al-Shuwaie',
    'عبدالله عبدل': 'Abdullah Abdl',
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
      {
        'name': 'محمود خليل الحصري',
        'category': 'مجود',
        'path': 'Husary_128kbps_Mujawwad',
      },
    ],
  };


  /// Verified high-fidelity EveryAyah reciters for full ayah video mode
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

  /// Completely untimed reciters across all surahs (safety valve active everywhere)
  static const Set<String> globallyUntimedReciterPaths = {
    'MaherAlMuaiqly128kbps',
    'Minshawy_Mujawwad_192kbps',
    'Yaser_Salamah_128kbps',
    'Ayman_Sowaid_64kbps',
    'mp3quran_107_128kbps',
    'mp3quran_108_128kbps',
    'mp3quran_126_128kbps',
    'mp3quran_127_128kbps',
    'mp3quran_182_128kbps',
    'mp3quran_136_128kbps',
    'mp3quran_149_128kbps',
    'mp3quran_160_128kbps',
    'mp3quran_161_128kbps',
    'mp3quran_163_128kbps',
    'mp3quran_164_128kbps',
    'mp3quran_165_128kbps',
    'mp3quran_18_128kbps',
    'mp3quran_197_128kbps',
    'mp3quran_202_128kbps',
    'mp3quran_206_128kbps',
    'mp3quran_10914_128kbps',
    'mp3quran_10915_128kbps',
    'mp3quran_10904_128kbps',
    'mp3quran_10906_128kbps',
    'mp3quran_10908_128kbps',
    'mp3quran_10909_128kbps',
    'mp3quran_10913_128kbps',
    'mp3quran_10917_128kbps',
    'mp3quran_10918_128kbps',
    'mp3quran_10922_128kbps',
    'mp3quran_10923_128kbps',
    'mp3quran_230_128kbps',
    'mp3quran_248_128kbps',
    'mp3quran_251_128kbps',
    'mp3quran_252_128kbps',
    'mp3quran_254_128kbps',
    'mp3quran_257_128kbps',
    'mp3quran_260_128kbps',
    'mp3quran_267_128kbps',
    'mp3quran_271_128kbps',
    'mp3quran_277_128kbps',
    'mp3quran_292_128kbps',
    'mp3quran_293_128kbps',
    'mp3quran_297_128kbps',
    'mp3quran_298_128kbps',
    'mp3quran_302_128kbps',
    'mp3quran_306_128kbps',
    'mp3quran_307_128kbps',
    'mp3quran_316_128kbps',
    'mp3quran_36_128kbps',
    'mp3quran_283_128kbps',
    'mp3quran_63_128kbps',
    'mp3quran_93_128kbps',
    'mp3quran_96_128kbps',
    'mp3quran_97_128kbps',
    'mp3quran_284_128kbps',
  };

  /// Specific surahs where certain reciters lack verified timings (safety valve active for that surah)
  static const Map<String, Set<int>> surahSpecificUntimedReciterPaths = {
    'Nabil_Rifa3i_48kbps': {27}, // Surah An-Naml
    'mp3quran_40_128kbps': {91}, // Surah Ash-Shams
    'Muhsin_Al_Qasim_192kbps': {4, 27}, // Surah An-Nisa & An-Naml
    'Abdullaah_3awwaad_Al-Juhaynee_128kbps': {4}, // Surah An-Nisa
    'mp3quran_259_128kbps': {1, 2}, // Surah Al-Fatihah & Al-Baqarah
  };

  /// List of MP3Quran reciter path keys that do not start with the 'mp3quran_' prefix
  static const Set<String> nonPrefixedMp3QuranPaths = {
    'Idrees_Abkar_128kbps',
    'Bandar_Balilah_128kbps',
    'Peshawa_Kurdi_128kbps',
    'Tawfeeq_AsSayegh_128kbps',
    'Khalid_AlJaleel_128kbps',
    'Raad_AlKurdi_128kbps',
    'Salah_AlBudair_128kbps',
    'Abdulbari_AlThubaiti_128kbps',
    'Abdulrahman_AlOssi_128kbps',
    'Abdulaziz_AlZahrani_128kbps',
    'Abdullah_AlBaijan_128kbps',
    'Abdullah_AlMousa_128kbps',
    'Mansoor_AlSalmi_128kbps',
    'Haitham_AlDukhin_128kbps',
    'Wadih_AlYamani_128kbps',
  };

  /// Checks whether a reciter uses MP3Quran (full surah audio) rather than EveryAyah (per-verse audio)
  static bool isMp3QuranReciter(String path) {
    return path.startsWith('mp3quran_') || nonPrefixedMp3QuranPaths.contains(path);
  }

  /// Checks whether a reciter has verified verse timings for a specific surah
  static bool hasTimingForSurah(String reciterPath, int surahNumber) {
    if (globallyUntimedReciterPaths.contains(reciterPath)) return false;
    final untimedSurahs = surahSpecificUntimedReciterPaths[reciterPath];
    if (untimedSurahs != null && untimedSurahs.contains(surahNumber)) {
      return false;
    }
    return true;
  }

  /// Returns reciters available for the given video text display mode, optionally filtered by surah and downloaded MP3Quran reciters
  static Map<String, List<Map<String, String>>> getVideoRecitersByCategory(
    VideoTextDisplayMode mode, {
    int? surahNumber,
    Set<String>? downloadedMp3QuranPaths,
  }) {
    final baseCatalog = (mode == VideoTextDisplayMode.staticFull)
        ? fullAyahVideoRecitersByCategory
        : verifiedVideoRecitersByCategory;

    final result = <String, List<Map<String, String>>>{};
    for (final entry in baseCatalog.entries) {
      final list = <Map<String, String>>[];
      for (final r in entry.value) {
        final path = r['path']!;
        if (globallyUntimedReciterPaths.contains(path)) continue;
        if (surahNumber != null && !hasTimingForSurah(path, surahNumber)) continue;
        list.add(r);
      }
      if (list.isNotEmpty) {
        result[entry.key] = list;
      }
    }

    // On native platforms (non-web), if user has downloaded MP3Quran reciters locally on disk, include them
    if (!kIsWeb && downloadedMp3QuranPaths != null && downloadedMp3QuranPaths.isNotEmpty) {
      for (final entry in reciterCategories.entries) {
        final category = entry.key;
        for (final reciterEntry in entry.value.entries) {
          final path = reciterEntry.value;
          if (isMp3QuranReciter(path) &&
              downloadedMp3QuranPaths.contains(path) &&
              !globallyUntimedReciterPaths.contains(path) &&
              (surahNumber == null || hasTimingForSurah(path, surahNumber))) {
            result.putIfAbsent(category, () => []).add({
              'name': reciterEntry.key,
              'category': category,
              'path': path,
            });
          }
        }
      }
    }

    return result;
  }

  /// Checks if the reciter is supported for the given display mode and surah
  static bool isReciterSupportedForMode(
    String reciterPath,
    VideoTextDisplayMode mode, {
    int? surahNumber,
    Set<String>? downloadedMp3QuranPaths,
  }) {
    final list = getVideoRecitersByCategory(
      mode,
      surahNumber: surahNumber,
      downloadedMp3QuranPaths: downloadedMp3QuranPaths,
    );
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

  /// Looks up a reciter path by reciter name across all categories, or within a specific category if provided
  static String getReciterPathByName(String reciterName, {String? category}) {
    if (category != null && reciterCategories.containsKey(category)) {
      final catMap = reciterCategories[category]!;
      if (catMap.containsKey(reciterName)) {
        return catMap[reciterName]!;
      }
    }
    for (final catMap in reciterCategories.values) {
      if (catMap.containsKey(reciterName)) {
        return catMap[reciterName]!;
      }
    }
    return defaultReciterPath;
  }
}


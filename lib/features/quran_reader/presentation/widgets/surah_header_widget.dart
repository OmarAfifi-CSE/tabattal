import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'quran_metadata.dart';

class SurahHeaderWidget extends StatelessWidget {
  final int surahNumber;

  const SurahHeaderWidget({
    super.key,
    required this.surahNumber,
  });

  String _toArabicNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  String _getSurahNameChar(int surahNumber) {
    // The surah_names.ttf font has a non-sequential mapping.
    // This array maps Surah 1-114 to their exact index from 0xE900.
    const fontMapping = <int>[
      0, // 0 (unused)
      4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, // 1-20
      26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 46, 47, 48, 49, 9, 10, 39, // 21-40
      40, 41, 42, 43, 44, 45, 50, 2, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 0, 1, // 41-60
      65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 61, 62, // 61-80
      63, 64, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, // 81-100
      101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114 // 101-114
    ];
    if (surahNumber < 1 || surahNumber > 114) return '';
    return String.fromCharCode(0xE900 + fontMapping[surahNumber]);
  }

  @override
  Widget build(BuildContext context) {
    final versesCount = QuranMetadata.surahLengthOf(surahNumber);
    final revelationPlace = QuranMetadata.getRevelationPlace(surahNumber);

    // We use the device screen width as our "Virtual Canvas" coordinate space.
    // This perfectly matches the dimensions you originally calibrated right/left/top on!
    final canvasWidth = MediaQuery.sizeOf(context).width;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      child: FittedBox(
        fit: BoxFit.fitWidth,
        child: SizedBox(
          width: canvasWidth, 
          height: 85,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. The decorative frame from QCF_BSML
              SizedBox(
                width: canvasWidth,
                child: Transform.scale(
                  scaleX: 1.0, // Fixed unified scale for all pages
                  scaleY: 1.8,
                  child: const FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text(
                      '\u00F2', 
                      style: TextStyle(
                        fontFamily: 'QCF_BSML',
                        fontSize: 60, 
                        color: AppColors.accentGold, 
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              
              // 2. The Surah Name from QCF_Surah
              Transform.translate(
                offset: const Offset(-5, 11), // User's manual center tweak
                child: Text(
                  '${_getSurahNameChar(surahNumber)}${String.fromCharCode(0xE903)}',
                  style: const TextStyle(
                    fontFamily: 'QCF_Surah',
                    fontSize: 46, 
                    color: AppColors.accentGold,
                    height: 1.0,
                  ),
                ),
              ),

              // 3. Right Oval Text (Verses count)
              Positioned(
                right: 66.0,
                top: 34,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'آياتها',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.accentGold,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      _toArabicNumbers(versesCount.toString()),
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.accentGold,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Left Oval Text (Revelation place)
              Positioned(
                left: 63.0,
                top: 38,
                child: Text(
                  revelationPlace,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.accentGold,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'quran_frame_painter.dart';

class QuranPageFrame extends StatelessWidget {
  final Widget child;
  final int pageNumber;
  final String surahName;
  final String juzName;

  const QuranPageFrame({
    super.key,
    required this.child,
    required this.pageNumber,
    required this.surahName,
    required this.juzName,
  });

  String _toArabicNumber(int number) {
    const englishToArabicDigits = {
      '0': '٠', '1': '١', '2': '٢', '3': '٣', '4': '٤',
      '5': '٥', '6': '٦', '7': '٧', '8': '٨', '9': '٩'
    };
    return number.toString().split('').map((e) => englishToArabicDigits[e] ?? e).join('');
  }

  @override
  Widget build(BuildContext context) {
    final Color innerColor = const Color(0xFF5A4033);
    final Color goldAccent = const Color(0xFFC7A263);

    return Scaffold(
      body: Container(
        // Premium radial paper texture/gradient
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFFFEFDFB), Color(0xFFF3EAD3)],
            radius: 1.5,
            center: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ----------------------------------------------------
              // LAYER 1: The Master Background Painter
              // ----------------------------------------------------
              CustomPaint(
                painter: QuranFramePainter(),
              ),

              // ----------------------------------------------------
              // LAYER 2: The Interactive Content
              // Constrained exactly inside the inner frame borders
              // Top border line is at Y=70, bottom border line is at Height-70
              // Side border lines are at X=22, Right=Width-22
              // ----------------------------------------------------
              Positioned(
                top: 75, // 5px padding from the top frame separator
                bottom: 75, // 5px padding from the bottom frame separator
                left: 32, // Padding from the left border
                right: 32, // Padding from the right border
                child: child,
              ),

              // ----------------------------------------------------
              // LAYER 3: Seamless Header Overlay
              // Overlaid exactly inside the top 48px box (Y=22 to Y=70)
              // ----------------------------------------------------
              Positioned(
                top: 22,
                height: 48,
                left: 22,
                right: 22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Juz Name
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        'الجزء $juzName',
                        style: TextStyle(color: innerColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    // Center: Empty (or could put an ornament here)

                    // Right: Surah Name and Menu Icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'سورة $surahName',
                          style: TextStyle(color: innerColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.menu_rounded, color: innerColor, size: 20),
                          onPressed: () {
                            // TODO: Open sidebar/menu
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 24,
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ],
                ),
              ),

              // ----------------------------------------------------
              // LAYER 4: Seamless Footer Overlay (Emblem)
              // Overlaid exactly inside the bottom 48px box 
              // ----------------------------------------------------
              Positioned(
                bottom: 22,
                height: 48,
                left: 22,
                right: 22,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Floral Emblem Background embedded into the border
                      Container(
                        width: 90,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EAD3),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.elliptical(45, 16),
                            right: Radius.elliptical(45, 16),
                          ),
                          border: Border.all(color: goldAccent, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      // Inner Diamond
                      Container(
                        width: 75,
                        height: 24,
                        decoration: BoxDecoration(
                          border: Border.all(color: goldAccent.withValues(alpha: 0.5), width: 1),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.elliptical(37, 12),
                            right: Radius.elliptical(37, 12),
                          ),
                        ),
                      ),
                      // The Arabic Page Number
                      Positioned(
                        top: 4, // Nudge to visually center the Arabic font
                        child: Text(
                          _toArabicNumber(pageNumber),
                          style: TextStyle(
                            color: innerColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
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

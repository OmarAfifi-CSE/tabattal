import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'quran_border_painter.dart';

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
    const Color innerColor = Color(0xFF2C2520); // Dark brown matching traditional ink

    // Traditional typography
    const TextStyle headerStyle = TextStyle(
      fontFamily: 'KFGQPC Uthmanic Script HAFS',
      color: innerColor, 
      fontSize: 10, 
      fontWeight: FontWeight.bold,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Let Scaffold background show through
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Material(
        color: const Color(0xFFfdf4e0), // The exact background color requested
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double W = constraints.maxWidth;
            final double H = constraints.maxHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                // ----------------------------------------------------
                // LAYER 1: Procedural Custom Painter Background
                // ----------------------------------------------------
                CustomPaint(
                  painter: QuranBorderPainter(),
                  size: Size.infinite,
                ),

                // ----------------------------------------------------
                // LAYER 2: The Interactive Content
                // Adjusted top constraint to clear the banners (pushed down ~24dp)
                // ----------------------------------------------------
                // Content constraints
                Positioned(
                  top: H * 0.08, 
                  bottom: H * 0.05, 
                  left: W * 0.08, 
                  right: W * 0.08, 
                  child: child,
                ),

                // ----------------------------------------------------
                // LAYER 3: Texts aligned with the frame cuts
                // ----------------------------------------------------
                // Juz Name
                Positioned(
                  top: H * 0.05, // Pin exactly to the line
                  left: W * 0.08, // Match Cut 1 left
                  width: W * 0.35, // Wider for Juz name
                  child: FractionalTranslation(
                    translation: const Offset(0.0, -0.5), // Center vertically regardless of lines
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: QuranBorderPainter.gold.withValues(alpha: 0.6), width: 1.0),
                        borderRadius: BorderRadius.circular(12),
                        color: QuranBorderPainter.background,
                      ),
                      child: Text(
                        juzName,
                        style: headerStyle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

                // Surah Name
                Positioned(
                  top: H * 0.05,
                  left: W * 0.46, // Match Cut 2 left
                  width: W * 0.33,
                  child: FractionalTranslation(
                    translation: const Offset(0.0, -0.5),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: QuranBorderPainter.gold.withValues(alpha: 0.6), width: 1.0),
                        borderRadius: BorderRadius.circular(12),
                        color: QuranBorderPainter.background,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          surahName,
                          style: headerStyle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                // Hamburger Menu Icon
                Positioned(
                  top: H * 0.05,
                  right: W * 0.07, // Match Cut 3 right (0.93 means right is 0.07)
                  width: W * 0.11, // Cut width is 0.11 (from 0.82 to 0.93)
                  child: FractionalTranslation(
                    translation: const Offset(0.0, -0.5),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: QuranBorderPainter.gold.withValues(alpha: 0.6), width: 1.0),
                        borderRadius: BorderRadius.circular(12),
                        color: QuranBorderPainter.background,
                      ),
                      child: InkWell(
                        onTap: () {
                          Scaffold.of(context).openDrawer();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Icon(Icons.menu_rounded, color: QuranBorderPainter.gold, size: 24),
                      ),
                    ),
                  ),
                ),

                // ----------------------------------------------------
                // LAYER 4: Page Number (Bottom Cut)
                // ----------------------------------------------------
                Positioned(
                  bottom: H * 0.03, // Pin exactly to bottom line (1 - 0.97 = 0.03)
                  left: W * 0.42,
                  width: W * 0.16,
                  child: FractionalTranslation(
                    translation: const Offset(0.0, 0.5), // Center vertically
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: QuranBorderPainter.gold.withValues(alpha: 0.6), width: 1.0),
                        borderRadius: BorderRadius.circular(12),
                        color: QuranBorderPainter.background,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _toArabicNumber(pageNumber),
                          style: const TextStyle(
                            fontFamily: 'Amiri',
                            color: QuranBorderPainter.innerColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // LAYER 5: Blending Gradients (تسييح)
                // Top Gradient to melt into SafeArea
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 10, // Shrunk from 40 to 10 to protect the ornaments
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFfdf4e0),
                          const Color(0xFFfdf4e0).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Bottom Gradient to melt into SafeArea
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 10, // Shrunk from 40 to 10 to protect the ornaments
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFFfdf4e0),
                          const Color(0xFFfdf4e0).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ), // Closes Material
    ); // Closes AnnotatedRegion
  }
}

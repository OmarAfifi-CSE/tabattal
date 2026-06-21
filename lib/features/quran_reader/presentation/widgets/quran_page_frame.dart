import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

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
    final Color innerColor = const Color(0xFF2C2520); // Dark brown matching traditional ink

    // Traditional typography
    final TextStyle headerStyle = GoogleFonts.amiri(
      color: innerColor, 
      fontSize: 16, 
      fontWeight: FontWeight.bold,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Let Scaffold background show through
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFfdf4e0), // The exact background color requested
        body: LayoutBuilder(
          builder: (context, constraints) {
            final double W = constraints.maxWidth;
            final double H = constraints.maxHeight;

            return Stack(
              fit: StackFit.expand,
              children: [
                // ----------------------------------------------------
                // LAYER 1: The Master Background Asset
                // ----------------------------------------------------
                Image.asset(
                  'assets/images/quran_frame.webp',
                  fit: BoxFit.fill,
                ),

                // ----------------------------------------------------
                // LAYER 2: The Interactive Content
                // Adjusted top constraint to clear the banners (pushed down ~24dp)
                // ----------------------------------------------------
                Positioned(
                  top: H * 0.12, // Pushed down further to clear the banners perfectly
                  bottom: H * 0.09, // Clears the bottom border and emblem
                  left: W * 0.09, // Side breathing room
                  right: W * 0.09, 
                  child: child,
                ),

                // ----------------------------------------------------
                // LAYER 3: Seamless Header Overlay
                // Banners are at the very top of the asset
                // ----------------------------------------------------
                // Left Banner (Juz Name)
                Positioned(
                  top: H * 0.055, // Moved UP significantly to sit inside the banner
                  height: H * 0.05, 
                  left: W * 0.11, // Perfectly aligned horizontally inside the left banner
                  width: W * 0.33,
                  child: Center(
                    child: Text(
                      'الجزء ${_toArabicNumber(int.tryParse(juzName) ?? 1)}',
                      style: headerStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Right Banner (Surah Name)
                Positioned(
                  top: H * 0.055, // Moved UP significantly to sit inside the banner
                  height: H * 0.05,
                  right: W * 0.18, // Perfectly aligned horizontally inside the right banner
                  width: W * 0.33,
                  child: Center(
                    child: Text(
                      'سورة $surahName',
                      style: headerStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Hamburger Menu Icon in the top right corner
                Positioned(
                  top: H * 0.045, // Moved UP to align with the headers
                  right: W * 0.04, // Tucked cleanly into the corner
                  child: IconButton(
                    icon: Icon(Icons.menu_rounded, color: innerColor, size: 22),
                    onPressed: () {
                      // TODO: Open sidebar/menu
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 24,
                  ),
                ),

                // ----------------------------------------------------
                // LAYER 4: Styled & Repositioned Page Number
                // Nudged lower to perfectly center in the bottom space
                // ----------------------------------------------------
                Positioned(
                  bottom: H * 0.025, // Nudged downward to hit the exact center of the footer
                  left: 0,
                  right: 0,
                  height: H * 0.04,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF7F0).withValues(alpha: 0.8), // Cream tint
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFC7A263).withValues(alpha: 0.6), width: 1),
                      ),
                      child: Text(
                        _toArabicNumber(pageNumber),
                        style: GoogleFonts.amiri(
                          color: innerColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.2, // Fix vertical alignment of Amiri font inside container
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
    ), // Closes Scaffold
    ); // Closes AnnotatedRegion
  }
}

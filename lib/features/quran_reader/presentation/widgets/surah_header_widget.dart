import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SurahHeaderWidget extends StatelessWidget {
  final String surahName;
  final int surahNumber;

  const SurahHeaderWidget({
    super.key,
    required this.surahName,
    required this.surahNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 75, // Slightly reduced from 85
      margin: const EdgeInsets.only(left: 24.0, right: 24.0, top: 12.0, bottom: 4.0),
      child: CustomPaint(
        painter: _SurahHeaderPainter(),
        child: Center(
          child: SvgPicture.asset(
            'assets/surah_names/$surahNumber.svg',
            height: 42,
            colorFilter: const ColorFilter.mode(Color(0xFF2C2520), BlendMode.srcIn),
            clipBehavior: Clip.none, // Prevent cropping of Arabic diacritics
            placeholderBuilder: (BuildContext context) => Text(
              surahName,
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2C2520),
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SurahHeaderPainter extends CustomPainter {
  static const Color gold = Color(0xFFC7A263);
  static const Color background = Color(0xFFEAD8BA); // Matches the thick band color

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Outer cartouche
    final Path outerPath = Path();
    final double pointWidth = h * 0.4;
    
    outerPath.moveTo(pointWidth, 0);
    outerPath.lineTo(w - pointWidth, 0);
    outerPath.lineTo(w, h / 2);
    outerPath.lineTo(w - pointWidth, h);
    outerPath.lineTo(pointWidth, h);
    outerPath.lineTo(0, h / 2);
    outerPath.close();

    // Inner cartouche
    const double inset = 6.0;
    final Path innerPath = Path();
    innerPath.moveTo(pointWidth + inset / 2, inset);
    innerPath.lineTo(w - pointWidth - inset / 2, inset);
    innerPath.lineTo(w - inset, h / 2);
    innerPath.lineTo(w - pointWidth - inset / 2, h - inset);
    innerPath.lineTo(pointWidth + inset / 2, h - inset);
    innerPath.lineTo(inset, h / 2);
    innerPath.close();

    // 1. Fill the entire inner cartouche with subtle background
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = background.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill,
    );

    // 2. Draw thick outer gold border
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeJoin = StrokeJoin.miter,
    );

    // 3. Draw thin inner gold border (double border effect)
    canvas.drawPath(
      innerPath,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.miter,
    );

    // 4. Draw geometric corner decorations
    final Paint fillPaint = Paint()..color = gold..style = PaintingStyle.fill;
    
    // Draw small diamonds at the 6 inner vertices
    void drawSmallDiamond(Offset center) {
      final Path d = Path();
      d.moveTo(center.dx + 3, center.dy);
      d.lineTo(center.dx, center.dy + 3);
      d.lineTo(center.dx - 3, center.dy);
      d.lineTo(center.dx, center.dy - 3);
      d.close();
      canvas.drawPath(d, fillPaint);
    }

    drawSmallDiamond(Offset(pointWidth + inset / 2, inset));
    drawSmallDiamond(Offset(w - pointWidth - inset / 2, inset));
    drawSmallDiamond(Offset(pointWidth + inset / 2, h - inset));
    drawSmallDiamond(Offset(w - pointWidth - inset / 2, h - inset));

    // 5. Intricate tip decorations (Nested triangles/diamonds)
    // Left tip
    canvas.drawCircle(Offset(inset * 2.5, h / 2), 2.0, fillPaint);
    drawSmallDiamond(Offset(inset * 4, h / 2));
    
    // Right tip
    canvas.drawCircle(Offset(w - inset * 2.5, h / 2), 2.0, fillPaint);
    drawSmallDiamond(Offset(w - inset * 4, h / 2));

    // 6. Engraved lines inside the tips
    final Paint thinLine = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
      
    // Left tip lines
    canvas.drawLine(Offset(inset, h / 2), Offset(pointWidth + inset / 2, inset), thinLine);
    canvas.drawLine(Offset(inset, h / 2), Offset(pointWidth + inset / 2, h - inset), thinLine);

    // Right tip lines
    canvas.drawLine(Offset(w - inset, h / 2), Offset(w - pointWidth - inset / 2, inset), thinLine);
    canvas.drawLine(Offset(w - inset, h / 2), Offset(w - pointWidth - inset / 2, h - inset), thinLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

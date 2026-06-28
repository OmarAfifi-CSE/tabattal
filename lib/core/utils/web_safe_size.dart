import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_screenutil/flutter_screenutil.dart';

extension WebSafeSize on num {
  double get wSp => kIsWeb ? toDouble() : sp;
  double get wR => kIsWeb ? toDouble() : r;
  double get wH => kIsWeb ? toDouble() : h;
  double get wW => kIsWeb ? toDouble() : w;
}

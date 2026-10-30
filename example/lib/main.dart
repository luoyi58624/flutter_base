import 'package:android_system_font_weight/android_system_font_weight.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/mobile.dart';

import 'src/mobile/app.dart';

void main() {
  ElWidgetsFlutterBinding.ensureInitialized();
  final weight = AndroidSystemFontWeight.getWght();
  runApp(
    ElExampleApp(
      systemWght:
          weight != null && weight.isFinite && weight >= 100 && weight <= 1000
          ? weight
          : null,
    ),
  );
}

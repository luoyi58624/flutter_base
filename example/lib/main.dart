import 'package:android_system_font_weight/android_system_font_weight.dart';
import 'package:example/src/layout/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import 'src/mobile/app.dart';

void main() {
  ElWidgetsFlutterBinding.ensureInitialized();
  final weight = AndroidSystemFontWeight.getWght();
  runApp(
    const App(),
    // ElExampleApp(
    //   systemWght:
    //       weight != null && weight.isFinite && weight >= 100 && weight <= 1000
    //       ? weight
    //       : null,
    // ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: AppLayout());
  }
}

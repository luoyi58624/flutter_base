import 'package:android_system_font_weight/android_system_font_weight.dart';
import 'package:example/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'src/pages/index.dart';

void main() {
  ElWidgetsFlutterBinding.ensureInitialized();
  runApp(_App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final weight = AndroidSystemFontWeight.getWght();
    final variations = weight != null && weight.isFinite && weight >= 100 && weight <= 1000
        ? [FontVariation('wght', weight)]
        : null;
    return ElView(
      style: .new(fontVariations: variations),
      child: ObsBuilder(
        builder: (context) {
          return MaterialApp(showPerformanceOverlay: GlobalState.showPerformanceOverlay.value, home: HomePage());
        },
      ),
    );
  }
}

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
    return ObsBuilder(
      builder: (context) {
        return MaterialApp(showPerformanceOverlay: GlobalState.showPerformanceOverlay.value, home: HomePage());
      },
    );
  }
}

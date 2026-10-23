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
    return MaterialApp(showPerformanceOverlay: true, home: HomePage());
  }
}

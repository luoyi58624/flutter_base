import 'package:flutter/material.dart';

import 'src/pages/index.dart';
import 'src/pages/view.dart';

void main() => runApp(_App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(showPerformanceOverlay: true, home: HomePage());
  }
}

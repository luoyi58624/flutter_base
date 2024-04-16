import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

import 'controllers/index.dart';

void main() async {
  await initFlutterApp();
  initController();
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return FlutterApp(
      router: initRouter(),
    );
  }
}

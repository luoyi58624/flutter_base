import 'package:android_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

void main() async {
  await initFlutterApp(router: router);
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return const FlutterApp();
  }
}

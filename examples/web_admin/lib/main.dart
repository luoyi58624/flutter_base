import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:web_admin/pages/home.dart';

import 'router.dart';

void main() async {
  await initFlutterApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterApp(
      router: router,
    );
    // return MaterialApp(
    //   home: HomePage(),
    // );
  }
}

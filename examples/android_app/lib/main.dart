import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

import 'controllers/index.dart';

void main() async {
  await initFlutterApp();
  initController();
  runApp(App(
    router: initRouter(),
  ));
}

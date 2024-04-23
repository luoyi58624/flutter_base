import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

import 'controllers/index.dart';

void main() async {
  await initApp();
  initController();
  runApp(App.router(router: initRouter()));
}

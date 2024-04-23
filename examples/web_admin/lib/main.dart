import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'router.dart';

void main() async {
  await initApp();
  runApp(App.router(router: initRouter()));
}

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'router.dart';

void main() async {
  await initApp(router: initRouter());
  runApp(const App());
}

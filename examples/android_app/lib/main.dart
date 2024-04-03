import 'package:android_app/router.dart';
import 'package:flutter_base/flutter_base.dart';

import 'controllers/index.dart';

void main() async {
  await initFlutterApp(initRouter());
  initController();
  runApp(const FlutterApp());
}

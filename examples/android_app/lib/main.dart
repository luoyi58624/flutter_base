import 'package:android_app/controllers/global.dart';
import 'package:android_app/global.dart';
import 'package:flutter/gestures.dart';

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
    return Obx(
      () => FlutterApp(
        router: initRouter(),
        config: FlutterConfigData(
          useMaterial3: GlobalController.of.useMaterial3.value,
        ),
      ),
    );
  }
}

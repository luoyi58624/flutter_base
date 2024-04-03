import 'package:android_app/controllers/global.dart';
import 'package:android_app/global.dart';
import 'package:android_app/router.dart';
import 'package:flutter_base/flutter_base.dart';

import 'controllers/index.dart';

void main() async {
  await initFlutterApp(initRouter());
  initController();
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => FlutterApp(
        config: FlutterConfigData(
          useMaterial3: GlobalController.of.useMaterial3.value,
        ),
      ),
    );
  }
}

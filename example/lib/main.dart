import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:example/global.dart';

import 'pages/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initStorage();
  await FlutterFont.init();
  await FlutterFont.initSystemFontWeight();
  initController();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppController c = Get.find();
    return Obx(() {
      return AppWidget(
          data: c.appData.value,
          child: Obx(() => MaterialApp(
                navigatorKey: rootNavigatorKey,
                debugShowCheckedModeBanner: false,
                showPerformanceOverlay: c.showPerformanceOverlay.value,
                themeMode: c.themeMode.value,
                theme: AppWidget.buildThemeData(data: c.appData.value, brightness: Brightness.light),
                darkTheme: AppWidget.buildThemeData(data: c.appData.value, brightness: Brightness.dark),
                home: const HomePage(),
                builder: (context, child) => BrightnessWidget(
                  brightness: Theme.of(context).brightness,
                  child: Material(
                    child: CupertinoTheme(
                      data: AppWidget.buildCupertinoThemeData(
                          data: c.appData.value, brightness: Theme.of(context).brightness),
                      child: child!,
                    ),
                  ),
                ),
              )));
    });
  }
}

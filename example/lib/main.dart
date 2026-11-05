import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart';

import 'demo/test.dart';
import 'src/router/index.dart';
import 'src/state/index.dart';

void main() {
  ElWidgetsFlutterBinding.ensureInitialized();
  runApp(DemoTestApp());
  // runApp(App());
}

/// 根据可用宽度安装品牌预设和路由布局的示例应用。
class App extends StatelessWidget {
  /// 创建示例应用。
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ObsBuilder(
      builder: (context) => ElView(
        themeMode: ElThemeMode(brightness: GlobalState.isDark.value ? Brightness.dark : Brightness.light),
        child: Builder(
          builder: (context) {
            routingConfig.isMobile = context.sm;
            return ElView(
              style: (context.sm ? el.mobileComponents : el.desktopComponents).style,
              child: ObsBuilder(
                builder: (context) {
                  final theme = ElView.of(context).themeMode;
                  return MaterialApp.router(
                    routerConfig: router,
                    themeAnimationDuration: theme.duration!,
                    themeAnimationCurve: theme.curve!,
                    showPerformanceOverlay: GlobalState.showPerformanceOverlay.value,
                    debugShowCheckedModeBanner: GlobalState.debugShowCheckedModeBanner.value,
                    theme: context.elMaterialThemeData,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

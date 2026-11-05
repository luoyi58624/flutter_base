import 'package:android_system_font_weight/android_system_font_weight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart';

import 'src/router/index.dart';
import 'src/state/index.dart';

void main() {
  ElWidgetsFlutterBinding.ensureInitialized();
  // runApp(DemoTestApp());
  runApp(App(systemFontWeight: AndroidSystemFontWeight.getWght()));
}

/// 根据可用宽度安装品牌预设和路由布局的示例应用。
class App extends StatelessWidget {
  /// 创建示例应用。
  const App({super.key, this.systemFontWeight});

  /// 启动时读取的 Android 字重轴值，空值沿用默认字体。
  final double? systemFontWeight;

  @override
  Widget build(BuildContext context) {
    return ObsBuilder(
      builder: (context) => ElView(
        themeMode: ElThemeMode(brightness: GlobalState.isDark.value ? Brightness.dark : Brightness.light),
        style: systemFontWeight == null
            ? null
            : ElStyle(fontVariationSettings: [FontVariation('wght', systemFontWeight!)]),
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
                    builder: (context, child) => ObsBuilder(
                      builder: (context) => ExcludeSemantics(
                        key: ValueKey('app-exclude-semantics'),
                        excluding: GlobalState.excludeSemantics.value,
                        child: child,
                      ),
                    ),
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

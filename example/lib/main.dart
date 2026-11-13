import 'package:android_system_font_weight/android_system_font_weight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart';

import 'src/router/index.dart';
import 'src/state/index.dart';
import 'src/widgets/frame_recording_scope.dart';

Future<void> main() async {
  ElWidgetsFlutterBinding.ensureInitialized();
  await el.initStorage(key: 'flutter_base_example', debounceTime: 0);
  GlobalState.restoreSettings();
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
    return FrameRecordingScope(
      child: ObsBuilder(
        builder: (context) => ExcludeSemantics(
          excluding: GlobalState.excludeSemantics.value,
          child: ElView(
            themeMode: ElThemeMode(
              brightness: GlobalState.isDark.value ? Brightness.dark : Brightness.light,
              duration: GlobalState.closeAnimation.value ? Duration.zero : null,
            ),
            style: (GlobalState.globalFontWeight.value ?? systemFontWeight) == null
                ? null
                : ElStyle(
                    fontVariationSettings: [
                      FontVariation('wght', (GlobalState.globalFontWeight.value ?? systemFontWeight!).toDouble()),
                    ],
                  ),
            child: Builder(
              builder: (context) {
                routingConfig.isMobile = context.sm;
                return ObsBuilder(
                  builder: (context) => ElView(
                    style: (context.sm ? el.mobileComponents : el.desktopComponents).style?.merge(
                      GlobalState.appearanceStyle,
                    ),
                    child: ObsBuilder(
                      builder: (context) {
                        final theme = ElView.of(context).themeMode;
                        final materialTheme = context.elMaterialThemeData;
                        final weight = GlobalState.globalFontWeight.value;
                        TextTheme applyWeight(TextTheme text) {
                          final fontWeight = FontWeight.values[(weight! ~/ 100 - 1).clamp(0, 8)];
                          return text.copyWith(
                            bodyLarge: text.bodyLarge?.copyWith(fontWeight: fontWeight),
                            bodyMedium: text.bodyMedium?.copyWith(fontWeight: fontWeight),
                            bodySmall: text.bodySmall?.copyWith(fontWeight: fontWeight),
                          );
                        }

                        return MaterialApp.router(
                          routerConfig: router,
                          scrollBehavior: ElScrollBehavior(),
                          themeAnimationDuration: theme.duration!,
                          themeAnimationCurve: theme.curve!,
                          showPerformanceOverlay: GlobalState.showPerformanceOverlay.value,
                          debugShowCheckedModeBanner: GlobalState.debugShowCheckedModeBanner.value,
                          showSemanticsDebugger: GlobalState.showSemanticsDebugger.value,
                          locale: GlobalState.locale.value,
                          supportedLocales: GlobalState.supportedLocales.values,
                          localizationsDelegates: GlobalMaterialLocalizations.delegates,
                          theme: weight == null
                              ? materialTheme
                              : materialTheme.copyWith(
                                  textTheme: applyWeight(materialTheme.textTheme),
                                  primaryTextTheme: applyWeight(materialTheme.primaryTextTheme),
                                ),
                          builder: (context, child) => ObsBuilder(
                            builder: (context) {
                              final media = MediaQuery.of(context);
                              final scale = GlobalState.globalScale.value;
                              final weight = GlobalState.globalFontWeight.value;
                              return MediaQuery(
                                data: media.copyWith(
                                  textScaler: scale == 1 ? media.textScaler : TextScaler.linear(scale),
                                  disableAnimations: media.disableAnimations || GlobalState.closeAnimation.value,
                                ),
                                child: Directionality(
                                  textDirection: GlobalState.rtl.value ? TextDirection.rtl : Directionality.of(context),
                                  child: DefaultTextStyle.merge(
                                    style: TextStyle(
                                      fontWeight: weight == null
                                          ? null
                                          : FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        child!,
                                        if (GlobalState.showFps.value)
                                          PositionedDirectional(top: 8, end: 12, child: SafeArea(child: ElFps())),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

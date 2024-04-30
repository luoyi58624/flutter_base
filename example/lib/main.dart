import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:mini_getx/mini_getx.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return materialApp();
  }

  Widget materialApp() {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.light).copyWith(extensions: [
        const FlutterThemeData(),
      ]),
      darkTheme: ThemeData(brightness: Brightness.dark).copyWith(extensions: [
        const FlutterThemeData.dark(),
      ]),
      home: const HomePage(),
    );
  }

  Widget cupertinoApp() {
    return const CupertinoApp(
      theme: CupertinoThemeData(),
      home: CupertionHomePage(),
    );
  }

  Widget demoApp() {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        }),
      ).copyWith(extensions: [
        const FlutterThemeData(),
      ]),
      darkTheme: ThemeData(brightness: Brightness.dark).copyWith(extensions: [
        const FlutterThemeData.dark(),
      ]),
      home: const CupertionHomePage(),
      builder: (context, child) => CupertinoTheme(
        data: CupertinoThemeData(brightness: context.theme.brightness),
        child: child!,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
      ),
      body: Center(
        child: Column(
          children: [
            TapBuilder(builder: (isTap) {
              return HoverBuilder(builder: (isHover) {
                return Container(
                  width: 100,
                  height: 100,
                  color: context.currentTheme.primary.onTap(context, isTap).onHover(context, isHover),
                );
              });
            }),
            const SizedBox(height: 8),
            TapBuilder(
              onTap: () {
                setState(() {
                  count++;
                });
              },
              builder: (isTap) {
                return Container(
                  width: 100,
                  height: 100,
                  color: context.currentTheme.primary.onTap(context, isTap),
                  child: Text('count: $count'),
                );
              },
            ),
            // Container(
            //   width: 100,
            //   height: 100,
            //   color: FlutterTheme.theme(context).primary,
            //   child: Text('primary: ${FlutterTheme.theme(context).primary}'),
            // ),
            // Obx(() {
            //   return Container(
            //     width: 100,
            //     height: 100,
            //     color: themeController.darkTheme.primary,
            //   );
            // }),
            // Obx(() {
            //   return Container(
            //     width: 100,
            //     height: 100,
            //     color: themeController.theme.customColor,
            //   );
            // }),
            // Container(
            //   width: 100,
            //   height: 100,
            //   color: FlutterTheme.currentTheme(context).primary,
            // ),
            // Obx(() {
            //   return Container(
            //     width: 100,
            //     height: 100,
            //     color: themeController.currentTheme(context).customColor,
            //   );
            // }),
          ],
        ),
      ),
    );
  }
}

class CupertionHomePage extends StatelessWidget {
  const CupertionHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    i(Theme.of(context).extension<FlutterThemeData>());
    i(context.isDarkMode);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('首页'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            children: [
              CupertinoButton.filled(
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (context) => const DemoPage()),
                  );
                },
                child: Text('Hello: ${CupertinoTheme.of(context).brightness}'),
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 100,
                color: context.currentTheme.primary,
                child: Text('Hello: ${context.currentTheme.primary}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChildPage extends StatelessWidget {
  const ChildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('子页面'),
        previousPageTitle: '首页',
      ),
      child: Center(
        child: CupertinoButton.filled(
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const ChildPage()),
            );
          },
          child: Text('Hello: ${CupertinoTheme.of(context).brightness}'),
        ),
      ),
    );
  }
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

final _isDark = Obs(false);

class DemoTestApp extends StatelessWidget {
  const DemoTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ObsBuilder(
      builder: (context) {
        return ElComponentProvider(
          components: el.desktopComponents,
          themeMode: ElThemeMode(brightness: _isDark.value ? .dark : .light),
          child: ObsBuilder(
            builder: (context) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                themeMode: _isDark.value ? ThemeMode.dark : ThemeMode.light,
                theme: ThemeData(scaffoldBackgroundColor: context.elTheme.bgColor),
                darkTheme: ThemeData(brightness: .dark, scaffoldBackgroundColor: context.elTheme.bgColor),
                home: _Home(),
              );
            },
          ),
        );
      },
    );
  }
}

class _Home extends HookWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          ObsBuilder(
            builder: (context) {
              return Switch(value: _isDark.value, onChanged: (v) => _isDark.value = v);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ElView(
            style: .new(
              width: 100,
              height: 100,
              transition: [.all()],
              onDark: .new(backgroundColor: Colors.red),
            ),
          ),
          ElView(
            style: .new(
              width: 100,
              height: 100,
              transition: [.all(500.ms)],
              onDark: .new(backgroundColor: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

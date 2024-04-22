import 'dart:math';

import 'package:android_app/global.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

class ThemePage extends StatefulWidget {
  const ThemePage({super.key});

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App主题设置'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(children: [
            buildCell(),
            buildLightPrimaryTheme(),
            buildDarkPrimaryTheme(),
            ElevatedButton(
              onPressed: () {
                TabScaffoldController.of.addTabBadge(0, 1);
              },
              child: const Text('添加tabBadge'),
            ),
            ElevatedButton(
              onPressed: () {
                TabScaffoldController.of.clearTabBadge(0);
              },
              child: const Text('清除tabBadge'),
            ),
            ElevatedButton(
              onPressed: () {
                TabScaffoldController.of.pages[0].title = 'Home';
              },
              child: const Text('更新tab标题'),
            ),
            ElevatedButton(
              onPressed: () {
                TabScaffoldController.of.pages[0].title = '组件';
                TabScaffoldController.of.pages.refresh();
              },
              child: const Text('还原tab标题'),
            ),
            ElevatedButton(
              onPressed: () {
                TabScaffoldController.of.pages[0].icon = Icons.home;
                TabScaffoldController.of.pages.refresh();
              },
              child: const Text('更新tab图标'),
            ),
            ElevatedButton(
              onPressed: () {
                TabScaffoldController.of.pages[0].icon = Icons.token_outlined;
                TabScaffoldController.of.pages.refresh();
              },
              child: const Text('还原tab图标'),
            ),
            ElevatedButton(
              onPressed: () {
                TabScaffoldController.of.demoList[1] = Random().nextInt(1000);
              },
              child: Obx(() => Text('demoList: ${TabScaffoldController.of.demoList[1]} ')),
            ),
          ]),
        ),
      ),
    );
  }

  Widget buildCell() {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: () {
              AppController.of.themeMode = ThemeMode.dark;
            },
            title: const Text('启用Material3'),
            trailing: Obx(
              () => Switch(
                value: AppController.of.config.useMaterial3,
                onChanged: (v) {
                  AppController.of.config = AppController.of.config.copyWith(useMaterial3: v);
                },
              ),
            ),
          ),
          ListTile(
            onTap: () {
              AppController.of.themeMode = ThemeMode.dark;
            },
            title: const Text('开启性能监控'),
            trailing: Obx(
              () => Switch(
                value: AppController.of.config.showPerformanceOverlay,
                onChanged: (v) {
                  AppController.of.config = AppController.of.config.copyWith(showPerformanceOverlay: v);
                },
              ),
            ),
          ),
          ListTile(
            onTap: () {
              AppController.of.themeMode = ThemeMode.system;
            },
            title: const Text('跟随系统'),
            trailing: Obx(
              () => Radio<ThemeMode>(
                value: AppController.of.themeMode,
                onChanged: (ThemeMode? mode) {
                  AppController.of.themeMode = ThemeMode.system;
                },
                groupValue: ThemeMode.system,
              ),
            ),
          ),
          ListTile(
            onTap: () {
              AppController.of.themeMode = ThemeMode.light;
            },
            title: const Text('亮色模式'),
            trailing: Obx(
              () => Radio<ThemeMode>(
                value: AppController.of.themeMode,
                onChanged: (ThemeMode? mode) {
                  AppController.of.themeMode = ThemeMode.light;
                },
                groupValue: ThemeMode.light,
              ),
            ),
          ),
          ListTile(
            onTap: () {
              AppController.of.themeMode = ThemeMode.dark;
            },
            title: const Text('黑暗模式'),
            trailing: Obx(
              () => Radio<ThemeMode>(
                value: AppController.of.themeMode,
                onChanged: (ThemeMode? mode) {
                  AppController.of.themeMode = ThemeMode.dark;
                },
                groupValue: ThemeMode.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLightPrimaryTheme() {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: ExpansionTile(
        leading: const Icon(Icons.color_lens),
        title: const Text('亮色主题颜色'),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FlutterColorData.materialColors.map((color) {
                return InkWell(
                  onTap: () {
                    AppController.of.theme = AppController.of.theme.copyWith(primary: color);
                  },
                  child: Obx(
                    () => Container(
                      width: 40,
                      height: 40,
                      color: color,
                      child: AppController.of.theme.primary == color
                          ? const Icon(
                              Icons.done,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDarkPrimaryTheme() {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: ExpansionTile(
        leading: const Icon(Icons.color_lens),
        title: const Text('暗色主题颜色'),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FlutterColorData.materialColors.map((color) {
                return InkWell(
                  onTap: () {
                    AppController.of.darkTheme = AppController.of.darkTheme.copyWith(primary: color);
                  },
                  child: Obx(
                    () => Container(
                      width: 40,
                      height: 40,
                      color: color,
                      child: AppController.of.darkTheme.primary == color
                          ? const Icon(
                              Icons.done,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

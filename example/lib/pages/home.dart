import 'package:flutter/material.dart';
import 'package:example/global.dart';

import '../widgets/tab.dart';
import '../widgets/button.dart';
import '../widgets/cupertino.dart';
import '../widgets/form.dart';
import 'hook.dart';
import 'loading.dart';
import 'modal.dart';
import 'route.dart';

class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        centerTitle: false,
        actions: _buildActions(context),
      ),
      drawer: const Drawer(
        child: ListViewDemoWidget(),
      ),
      body: buildScrollWidget(
        child: ColumnWidget(children: [
          buildCardWidget(context, title: '通用组件', children: [
            buildCellWidget(context, title: 'Loading 测试', page: const LoadingPage()),
            buildCellWidget(context, title: 'Modal 测试', page: const ModalPage()),
            buildCellWidget(context, title: 'Hook 测试', page: const HookDemoPage()),
            buildCellWidget(context, title: 'Route 测试', page: const RoutePage()),
          ]),
          const Gap(8),
          const ButtonWidgets(),
          const FormWidgets(),
          const TabWidget(),
          const CupertinoWidgets(),
          ...List.generate(20, (index) => buildCellWidget(context, title: '列表 - ${index + 1}')),
        ]),
      ),
    );
  }
}

List<Widget> _buildActions(BuildContext context) => [
      Obx(() {
        return Switch(
          value: AppController.of.showPerformanceOverlay.value,
          onChanged: (v) => AppController.of.showPerformanceOverlay.value = v,
        );
      }),
      IconButton(
        onPressed: () {
          AppController.of.themeMode.value = BrightnessWidget.isDark(context) ? ThemeMode.light : ThemeMode.dark;
        },
        icon: Icon(BrightnessWidget.isDark(context) ? Icons.dark_mode : Icons.light_mode),
      ),
      Obx(
        () => IconButton(
          onPressed: () {
            AppController.of.appData.value.config.useMaterial3 = !AppController.of.appData.value.config.useMaterial3;
            AppController.of.appData.refresh();
          },
          icon: Icon(
            AppController.of.appData.value.config.useMaterial3 ? Icons.looks_3_outlined : Icons.looks_two_outlined,
          ),
        ),
      ),
      PopupMenuButton<int>(
        enableFeedback: true,
        offset: Offset(0, context.appConfig.appbarHeight + 4),
        popUpAnimationStyle: AnimationStyle.noAnimation,
        icon: const Icon(Icons.color_lens),
        onSelected: (value) {
          AppController.of.selectPresetTheme.value = value;
        },
        itemBuilder: (context) {
          return ['默认配置', 'M2默认主题', 'M2扁平化配置', 'M3默认主题', 'M3扁平化配置']
              .mapIndexed((index, value) => PopupMenuItem(
                    height: 40,
                    value: index,
                    child: Row(
                      children: [
                        if (index == AppController.of.selectPresetTheme.value)
                          Icon(
                            Icons.check,
                            color: context.appTheme.iconColor,
                          ).padding(right: 8),
                        Text(value),
                      ],
                    ),
                  ))
              .toList();
        },
      ),
    ];

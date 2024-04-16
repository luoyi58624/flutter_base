import 'dart:math';

import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

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
        child: Column(children: [
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
              // TabScaffoldController.of.pages.
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
          // buildCell(),
          // const SizedBox(height: 8),
          // buildPrimaryTheme(),
        ]),
      ),
    );
  }

// Widget buildCell() {
//   return Card(
//     elevation: 2,
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         ListTile(
//           title: const Text('黑暗模式'),
//           trailing: Obx(
//             () => Switch(
//               value: ThemeController.of.useDark.value,
//               onChanged: (bool value) {
//                 ThemeController.of.useDark.value = value;
//               },
//             ),
//           ),
//         ),
//       ],
//     ),
//   );
// }

// Widget buildPrimaryTheme() {
//   return Card(
//     elevation: 2,
//     clipBehavior: Clip.hardEdge,
//     child: ExpansionTile(
//       leading: const Icon(Icons.color_lens),
//       title: const Text('主题颜色'),
//       initiallyExpanded: true,
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 8),
//           child: Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: colorList.map((color) {
//               return InkWell(
//                 onTap: () {
//                   ThemeController.of.primaryColor.value = color;
//                 },
//                 child: Obx(
//                   () => Container(
//                     width: 40,
//                     height: 40,
//                     color: color,
//                     // ignore: unrelated_type_equality_checks
//                     child: ThemeController.of.primaryColor.value == color
//                         ? const Icon(
//                             Icons.done,
//                             color: Colors.white,
//                           )
//                         : null,
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//       ],
//     ),
//   );
// }
}

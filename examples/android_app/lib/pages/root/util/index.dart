import 'package:android_app/pages/root/util/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'animation_test.dart';
import 'async_test.dart';
import 'custom_painter_test.dart';
import 'getx_util/page.dart';
import 'inherited_widget_test.dart';
import 'local_storage_test.dart';

class UtilPage extends StatelessWidget {
  const UtilPage({super.key});

  @override
  Widget build(BuildContext context) {
    List<PageNavModel> utilCellItems = [
      PageNavModel('Getx工具类测试', const GetxUtilPage()),
      // PageNavModel('GetxDemo', GetxDemoPage()),
      PageNavModel('InheritedWidget测试', const InheritedWidgetTestPage()),
      PageNavModel('本地存储测试', const LocalStorageTestPage()),
      PageNavModel('异步函数测试', const AsyncTestPage()),
      PageNavModel('动画测试', const AnimationTestPage()),
      PageNavModel('自定义绘制', const CustomPainterTestPage()),
      PageNavModel('Toast测试', const ToastTestPage()),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('工具列表'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildListSection(context, '工具类测试', utilCellItems),
          ],
        ),
      ),
    );
  }
}

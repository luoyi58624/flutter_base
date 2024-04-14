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
    ScrollController controller = ScrollController();
    List<PageNavModel> utilCellItems = [
      const PageNavModel('Getx工具类测试', GetxUtilPage()),
      // PageNavModel('GetxDemo', GetxDemoPage()),
      const PageNavModel('InheritedWidget测试', InheritedWidgetTestPage()),
      const PageNavModel('本地存储测试', LocalStorageTestPage()),
      const PageNavModel('异步函数测试', AsyncTestPage()),
      const PageNavModel('动画测试', AnimationTestPage()),
      const PageNavModel('自定义绘制', CustomPainterTestPage()),
      const PageNavModel('Toast测试', ToastTestPage()),
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

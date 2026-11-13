import 'package:example/src/pages/components/feedback/popover/examples/example2.dart' as popover2;
import 'package:example/src/pages/components/feedback/popup_menu/examples/example1.dart' as menu1;
import 'package:example/src/pages/components/feedback/popup_menu/examples/example2.dart' as menu2;
import 'package:example/src/pages/components/feedback/popup_menu/examples/example3.dart' as menu3;
import 'package:example/src/pages/components/feedback/popup_menu/examples/example4.dart' as menu4;
import 'package:example/src/pages/components/feedback/tooltip/examples/example1.dart' as tooltip1;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

Finder _copy(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text || w is ElView && w.child == text);

Finder _button(Object child) => find.byWidgetPredicate((w) => w is ElButton && w.child == child);

// 菜单文字所在的 ElView 不单独命中，点击落在所在行上。
Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tapAt(tester.getCenter(_copy(label)));
  await tester.pumpAndSettle();
}

Future<void> _host(WidgetTester tester, Widget example, ElComponents components) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => ElComponentProvider(components: components, child: child!),
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: example),
        ),
      ),
    ),
  );
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('桌面提示示例：悬停按钮在对应方位显示提示', (tester) async {
    await _host(tester, tooltip1.Example1(), el.desktopComponents);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(1, 1));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(_button('bottomEnd')));
    await tester.pump(Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final tip = tester.getRect(_copy('bottomEnd 方位的提示'));
    final button = tester.getRect(_button('bottomEnd'));
    expect(tip.top, greaterThan(button.bottom));
    expect(tip.right, closeTo(button.right, .01));
    await _dispose(tester);
  });

  testWidgets('移动提示示例：点击显示提示', (tester) async {
    await _host(tester, tooltip1.Example1(), el.mobileComponents);
    await tester.tap(_button('bottom'));
    await tester.pumpAndSettle();
    expect(tester.getRect(_copy('bottom 方位的提示')).top, greaterThan(tester.getRect(_button('bottom')).bottom));
    await _dispose(tester);
  });

  for (final (brand, components) in [('桌面', el.desktopComponents), ('移动', el.mobileComponents)]) {
    testWidgets('$brand弹出框示例：卡片内按钮经控制器关闭并回调状态', (tester) async {
      await _host(tester, popover2.Example2(), components);
      expect(_copy('弹出框已关闭'), findsOneWidget);
      await tester.tap(_button('删除记录'));
      await tester.pumpAndSettle();
      expect(_copy('弹出框已打开'), findsOneWidget);
      await tester.tap(_button('删除'));
      await tester.pumpAndSettle();
      expect(_button('删除'), findsNothing);
      expect(_copy('弹出框已关闭'), findsOneWidget);
      expect(_copy('已删除'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('$brand下拉菜单示例：禁用项不响应，选择后关闭并提示', (tester) async {
      await _host(tester, menu1.Example1(), components);
      await tester.tap(_button('下方右对齐'));
      await tester.pumpAndSettle();
      expect(_copy('Ctrl+E'), findsOneWidget);
      await _tap(tester, '移动到');
      expect(_copy('Ctrl+E'), findsOneWidget);
      await _tap(tester, '复制链接');
      expect(_copy('Ctrl+E'), findsNothing);
      expect(_copy('复制链接'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('$brand溢出菜单示例：从按钮所在位置展开', (tester) async {
      await _host(tester, menu2.Example2(), components);
      final button = tester.getRect(_button(Icons.more_vert));
      await tester.tap(_button(Icons.more_vert));
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.ancestor(of: _copy('刷新'), matching: find.byType(FadeTransition)).first);
      expect(panel.top, closeTo(button.top, .01));
      expect(panel.right, closeTo(button.right, .01));
      await _tap(tester, '分享');
      expect(_copy('刷新'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('$brand右键菜单示例：右键与长按在指针位置展开', (tester) async {
      await _host(tester, menu3.Example3(), components);
      final area = tester.getRect(_copy('在此区域右键或长按'));
      await tester.tapAt(area.center, buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.ancestor(of: _copy('新建文件'), matching: find.byType(FadeTransition)).first);
      expect(panel.left, closeTo(area.center.dx, .01));
      await _tap(tester, '刷新');
      expect(_copy('新建文件'), findsNothing);

      await tester.longPressAt(area.centerLeft + Offset(20, 0));
      await tester.pumpAndSettle();
      expect(_copy('新建文件'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('$brand多级菜单示例：逐级展开，选择三级子项后整条关闭', (tester) async {
      await _host(tester, menu4.Example4(), components);
      await tester.tap(_button('点击打开'));
      await tester.pumpAndSettle();
      await _tap(tester, '导出为');
      await _tap(tester, '更多格式');
      await _tap(tester, 'SVG');
      expect(_copy('显示网格'), findsNothing);
      expect(_copy('PNG 图片'), findsNothing);
      expect(_copy('导出 SVG'), findsOneWidget);
      await _dispose(tester);
    });
  }
}

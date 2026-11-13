import 'package:example/src/pages/components/feedback/dialog/examples/example1.dart' as dialog1;
import 'package:example/src/pages/components/feedback/dialog/examples/example2.dart' as dialog2;
import 'package:example/src/pages/components/feedback/dialog/examples/example3.dart' as dialog3;
import 'package:example/src/pages/components/feedback/dialog/examples/example4.dart' as dialog4;
import 'package:example/src/pages/components/feedback/drawer/examples/example2.dart' as drawer2;
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

Finder _copy(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.data == text || w is ElView && w.child == text);

Finder _button(String label) => find.byWidgetPredicate((w) => w is ElButton && w.child == label);

Future<void> _host(WidgetTester tester, Widget example, ElComponents components) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => ElComponentProvider(components: components, child: child!),
      home: Scaffold(body: Center(child: example)),
    ),
  );
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(SizedBox());
  await tester.pump();
}

void main() {
  for (final (brand, components) in [('桌面', el.desktopComponents), ('移动', el.mobileComponents)]) {
    testWidgets('$brand对话框示例：页脚按钮返回所选套餐', (tester) async {
      await _host(tester, dialog1.Example1(), components);
      await tester.tap(_button('返回结果'));
      await tester.pumpAndSettle();
      await tester.tap(_button('专业版'));
      await tester.pumpAndSettle();
      expect(find.byType(ElDialog), findsNothing);
      expect(_copy('已选择专业版'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('$brand确认框示例：不可关闭的对话框只响应按钮', (tester) async {
      await _host(tester, dialog2.Example2(), components);
      await tester.tap(_button('必须选择'));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(ElDialog), findsOneWidget);
      await tester.tap(_button('同意'));
      await tester.pumpAndSettle();
      expect(_copy('已同意'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('$brand输入框示例：超长名称被拦下，合法名称写回页面', (tester) async {
      await _host(tester, dialog3.Example3(), components);
      await tester.tap(_button('重命名'));
      await tester.pumpAndSettle();
      tester.testTextInput.enterText('一个超过二十个字符限制的非常非常长的项目名称');
      await tester.pump();
      await tester.testTextInput.receiveAction(.done);
      await tester.pumpAndSettle();
      expect(_copy('名称最多 20 个字符'), findsOneWidget);
      tester.testTextInput.enterText('季度规划');
      await tester.pump();
      await tester.testTextInput.receiveAction(.done);
      await tester.pumpAndSettle();
      expect(find.byType(ElDialog), findsNothing);
      expect(_copy('当前名称：季度规划'), findsOneWidget);
    });

    testWidgets('$brand底部面板示例：点选列表项返回分享目标', (tester) async {
      await _host(tester, dialog4.Example4(), components);
      await tester.tap(_button('底部面板'));
      await tester.pumpAndSettle();
      final panel = find.descendant(of: find.byType(ElDialog), matching: find.byType(ElView)).first;
      expect(tester.getRect(panel).bottom, greaterThan(tester.getSize(find.byType(Scaffold)).height - 40));
      await tester.tap(_copy('邮件').last);
      await tester.pumpAndSettle();
      expect(_copy('已分享到邮件'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('$brand抽屉示例：选择筛选项后关闭抽屉并写回页面', (tester) async {
      await _host(tester, drawer2.Example2(), components);
      await tester.tap(_button('打开筛选'));
      await tester.pumpAndSettle();
      await tester.tap(_copy('已完成').last);
      await tester.pumpAndSettle();
      expect(find.byType(ElDrawer), findsNothing);
      expect(_copy('当前筛选：已完成'), findsOneWidget);

      await tester.tap(_button('打开筛选'));
      await tester.pumpAndSettle();
      // 页脚按钮保持自身宽度，点在文字上。
      await tester.tap(_copy('重置筛选').last);
      await tester.pumpAndSettle();
      expect(_copy('当前筛选：全部'), findsOneWidget);
    });
  }
}

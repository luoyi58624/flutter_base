import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/src/widgets/panel.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _locate(WidgetTester tester, String input) async {
  await _tap(tester, 'selection-menu');
  await _tap(tester, 'selection-locate-menu');
  await tester.enterText(_key('selection-index-input'), input);
  await _tap(tester, 'selection-locate');
}

bool _checked(WidgetTester tester, String title) {
  final row = find.ancestor(of: find.text(title).hitTestable(), matching: find.byType(ExamplePanel)).first;
  final checkbox = find.descendant(of: row, matching: find.byType(ElCheckbox));
  return tester.widget<ElCheckbox>(checkbox).modelValue!.value as bool;
}

void main() {
  for (final mode in ['recycler', 'official']) {
    testWidgets('$mode 换绑和布局切换保留业务选择，清空同时移除离屏选择', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.mobileComponents,
          child: MaterialApp(home: RecyclerSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'selection-menu');
      expect(find.byType(CheckedPopupMenuItem<Object>), findsNWidgets(2));
      await _tap(tester, 'selection-mode-$mode');
      await _locate(tester, '5000');
      final target = find.text('条目 05000').hitTestable();
      expect(target, findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_key('selection-count')).data, '1 / 10000');
      await _locate(tester, '20000');
      expect(find.text('条目 10000').hitTestable(), findsOneWidget);
      expect(_checked(tester, '条目 10000'), isFalse, reason: '复用后的行不能继承旧业务 ID 的选中状态。');
      await tester.tap(find.text('条目 10000').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_key('selection-count')).data, '2 / 10000');
      await _locate(tester, '无效');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await _locate(tester, '5000');
      expect(_checked(tester, '条目 05000'), isTrue);
      await _tap(tester, 'selection-menu');
      await _tap(tester, 'selection-mode-${mode == 'recycler' ? 'official' : 'recycler'}');
      await _locate(tester, '5000');
      expect(_checked(tester, '条目 05000'), isTrue);
      await _tap(tester, 'selection-menu');
      await _tap(tester, 'selection-clear');
      expect(tester.widget<Text>(_key('selection-count')).data, '0 / 10000');
      expect(_checked(tester, '条目 05000'), isFalse);
      await _locate(tester, '10000');
      expect(_checked(tester, '条目 10000'), isFalse);
      await tester.tap(find.text('条目 10000').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_key('selection-count')).data, '1 / 10000');
      await _locate(tester, '5000');
      expect(_checked(tester, '条目 05000'), isFalse, reason: '固定行中的回调应读取当前 ID，不能重新选中旧绑定。');
      await tester.pumpWidget(SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}

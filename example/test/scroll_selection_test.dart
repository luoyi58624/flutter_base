import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:example/src/pages/examples/scroll_examples/comparison_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/src/widgets/panel.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _open(WidgetTester tester) async {
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
}

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
    final access = mode == 'recycler' ? '远跳只生成目标窗口' : '近跳和回访保留记录';
    testWidgets('$mode 离屏选择独立于记录创建，$access', (tester) async {
      await _open(tester);
      if (mode == 'official') {
        await _tap(tester, 'selection-menu');
        await _tap(tester, 'selection-mode-official');
      }
      final listFinder = find.byType(SliverComparisonList);
      final list = tester.widget<SliverComparisonList>(listFinder);
      final frame = list.itemBuilder(tester.element(listFinder), 0) as RepaintBoundary;
      // 通过现有行配置检查仓库，选择未访问记录无需提前构造其全部文案。
      final dynamic row = frame.child;
      final dynamic records = row.records;
      final Map items = records.items;
      expect(list.itemCount, 10000);
      expect(items.length, inInclusiveRange(1, 40));
      final initialCount = items.length;
      final targetIndex = mode == 'recycler' ? 7500 : 40;
      final targetTitle = '条目 ${(targetIndex + 1).toString().padLeft(5, '0')}';
      records.select(targetIndex, true);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_key('selection-count')).data, '1 / 10000');
      expect(items.length, initialCount);
      expect(items.containsKey(targetIndex), isFalse);
      // 官方自然高度列表的定位需布局中间行，近跳验证状态即可，不施加远跳压力。
      list.controller.jumpTo(targetIndex * 88.0);
      await tester.pumpAndSettle();
      expect(_checked(tester, targetTitle), isTrue);
      final target = items[targetIndex];
      expect(target, isNotNull);
      expect(items.length, lessThan(100));
      if (mode == 'recycler') expect(items.containsKey(4000), isFalse);
      final countBeforeRemoteSelection = items.length;
      records.select(9000, true);
      expect(items.length, countBeforeRemoteSelection);
      expect(items.containsKey(9000), isFalse);

      list.controller.jumpTo(0);
      await tester.pumpAndSettle();
      await _tap(tester, 'selection-menu');
      await _tap(tester, 'selection-clear');
      expect(tester.widget<Text>(_key('selection-count')).data, '0 / 10000');
      list.controller.jumpTo(targetIndex * 88.0);
      await tester.pumpAndSettle();
      expect(items[targetIndex], same(target));
      expect(_checked(tester, targetTitle), isFalse);
      expect((records.selectedIds as Set).contains(9000), isFalse);
      expect(items.containsKey(9000), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
      expect(items, isEmpty);
    });

    testWidgets('$mode 换绑和布局切换保留业务选择，清空同时移除离屏选择', (tester) async {
      await _open(tester);
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

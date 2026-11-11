import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/src/widgets/panel.dart';

void main() {
  for (final mode in ['recycler', 'official']) {
    testWidgets('$mode 点击标题、说明、空白和复选框各切换一次，拖动不误选', (tester) async {
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
      await tester.tap(find.byKey(ValueKey('selection-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('selection-mode-$mode')));
      await tester.pumpAndSettle();
      final title = find.text('条目 00001');
      final row = find.ancestor(of: title, matching: find.byType(ExamplePanel)).first;
      final checkbox = find.descendant(of: row, matching: find.byType(ElCheckbox));
      final scroll = find.byKey(ValueKey('comparison-$mode-list'));
      final scrollWidget = tester.widget(scroll);
      final titleWidget = tester.widget(title);
      final neighbor = find.ancestor(of: find.text('条目 00002'), matching: find.byType(ExamplePanel)).first;
      final neighborWidget = tester.widget(neighbor);
      final page = tester.element(find.byType(RecyclerSelectionPage));
      var pageBuilds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        if (identical(element, page)) pageBuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);

      void selected(bool value) {
        expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, value ? '1 / 10000' : '0 / 10000');
        expect(tester.widget<ElCheckbox>(checkbox).modelValue!.value, value);
        expect(tester.widget(scroll), same(scrollWidget), reason: '选中变化只更新目标行和计数，不替换列表配置。');
        expect(tester.widget(title), same(titleWidget));
        expect(tester.widget(neighbor), same(neighborWidget));
        expect(pageBuilds, 0, reason: '两种容器都通过已绑定行同步选择，不重建整页。');
      }

      await tester.tap(title);
      await tester.pumpAndSettle();
      selected(true);
      await tester.tap(find.text('记录 1 · 分组 1 · 独立业务编号 RV-100000'));
      await tester.pumpAndSettle();
      selected(false);
      final rect = tester.getRect(row);
      await tester.tapAt(Offset(rect.center.dx, rect.bottom - 5));
      await tester.pumpAndSettle();
      selected(true);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      selected(false);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      selected(true);
      await tester.tap(title);
      await tester.pumpAndSettle();
      selected(false);
      await tester.tap(find.byKey(ValueKey('selection-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('selection-clear')));
      await tester.pumpAndSettle();
      selected(false);
      await tester.timedDrag(scroll, Offset(0, -140), Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, '0 / 10000');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    });
  }
}

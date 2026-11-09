import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

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
      final row = find.ancestor(of: title, matching: find.byType(ElCardView)).first;
      final checkbox = find.descendant(of: row, matching: find.byType(ElCheckbox));
      void selected(bool value) {
        expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, value ? '1 / 10000' : '0 / 10000');
        expect(tester.widget<ElCheckbox>(checkbox).modelValue!.value, value);
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
      final scroll = find.byKey(ValueKey('comparison-$mode-list'));
      await tester.timedDrag(scroll, Offset(0, -140), Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, '0 / 10000');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    });
  }
}

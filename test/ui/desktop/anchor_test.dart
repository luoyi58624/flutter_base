import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('目录用键盘和鼠标回写模型，外部值与阻止默认事件生效', (tester) async {
    final selection = ValueNotifier<int?>(null);
    addTearDown(selection.dispose);
    var preventSelection = false;
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.desktopComponents,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 160,
              child: ElAnchor(
                links: ['同名小节', '同名小节'],
                modelValue: selection,
                event: ElEvent(
                  onTap: (event) {
                    if (preventSelection) event.preventDefault();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final rows = find.byType(ElButtonView);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selection.value, 0);

    await tester.tap(rows.last);
    await tester.pumpAndSettle();
    expect(selection.value, 1);
    expect(tester.widget<ElButtonView>(rows.last).semantics?.properties.selected, isTrue);

    selection.value = 0;
    await tester.pumpAndSettle();
    expect(tester.widget<ElButtonView>(rows.first).semantics?.properties.selected, isTrue);

    preventSelection = true;
    await tester.tap(rows.last);
    await tester.pumpAndSettle();
    expect(selection.value, 0);
    await tester.pumpWidget(SizedBox());
  });
}

import 'package:flutter_base/desktop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// normal / compact 两态尺寸及变量覆盖顺序。
void main() {
  Widget host(Widget child, {bool compact = false}) => Directionality(
    textDirection: TextDirection.ltr,
    child: ElComponentProvider(
      components: el.desktopComponents,
      child: ElView(
        style: ElStyle(vars: {ElementPlusThemeData.$compact: compact}),
        child: child,
      ),
    ),
  );

  ElRenderView button(WidgetTester tester) => tester.renderObject<ElRenderView>(
    find.descendant(of: find.byType(ElButton), matching: find.byType(ElButtonView)).first,
  );

  double inputHeight(WidgetTester tester) => tester
      .renderObject<ElRenderView>(find.descendant(of: find.byType(ElInput), matching: find.byType(ElView)).first)
      .size
      .height;

  testWidgets('normal / compact 直接决定按钮盒尺寸及字号', (tester) async {
    for (final compact in [false, true]) {
      await tester.pumpWidget(host(ElButton(child: '按钮'), compact: compact));
      await tester.pumpAndSettle();
      final render = button(tester);
      expect(render.size.height, compact ? 32 : 36);
      expect(render.style!.fontSize, compact ? 13 : 14);
      expect(render.style!.padding, EdgeInsets.symmetric(vertical: 4, horizontal: compact ? 14 : 16));
      expect(render.style!.borderRadius, BorderRadius.all(Radius.circular(4)));
    }
  });

  testWidgets('全局 compact 动态变化会更新复用的按钮与输入框', (tester) async {
    var compact = false;
    late StateSetter rebuild;
    final child = Column(
      children: [
        ElButton(child: '按钮'),
        ElInput(value: ''),
      ],
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ElComponentProvider(
              components: el.desktopComponents,
              child: ElView(
                style: ElStyle(vars: {ElementPlusThemeData.$compact: compact}),
                child: child,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(button(tester).size.height, 36);
    expect(inputHeight(tester), 36);
    rebuild(() => compact = true);
    await tester.pumpAndSettle();
    expect(button(tester).size.height, 32);
    expect(inputHeight(tester), 32);
  });

  testWidgets('普通 ElView 局部声明可以覆盖全局 compact', (tester) async {
    await tester.pumpWidget(
      host(
        ElView(
          style: ElStyle(vars: {ElementPlusThemeData.$compact: false}),
          child: ElButton(child: '按钮'),
        ),
        compact: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(button(tester).size.height, 36);
  });

  testWidgets('组件自身 style.vars 的 compact 优先于祖先声明', (tester) async {
    await tester.pumpWidget(
      host(
        ElButton(
          style: ElStyle(vars: {ElementPlusThemeData.$compact: false}),
          child: '按钮',
        ),
        compact: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(button(tester).size.height, 36);
    await tester.pumpWidget(
      host(
        ElButton(
          style: ElStyle(vars: {ElementPlusThemeData.$compact: true}),
          child: '按钮',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(button(tester).size.height, 32);
  });

  testWidgets('按钮图标随密度变化，与文字间隔保持 6', (tester) async {
    for (final compact in [false, true]) {
      await tester.pumpWidget(
        host(
          ElButton(child: '按钮', icon: ElDesktopIcons.menu),
          compact: compact,
        ),
      );
      await tester.pumpAndSettle();
      final icons = tester.widgetList<ElIcon>(
        find.descendant(of: find.byType(ElButton), matching: find.byType(ElIcon)),
      );
      final iconSize = compact ? 13.0 : 15.0;
      expect(icons.map((icon) => tester.getSize(find.byWidget(icon))), [Size.square(iconSize)]);
      final gaps = find.descendant(
        of: find.byType(ElButton),
        matching: find.byWidgetPredicate((widget) => widget is ElView && widget.child == null),
      );
      expect(gaps.evaluate().map((gap) => tester.getSize(find.byWidget(gap.widget)).width), [6.0]);
    }
  });

  testWidgets('显式 style 高度覆盖两态默认，不再依赖全局高度表', (tester) async {
    for (final compact in [false, true]) {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              ElButton(style: ElStyle(height: 45), child: '按钮'),
              ElInput(style: ElStyle(height: 41), value: ''),
            ],
          ),
          compact: compact,
        ),
      );
      await tester.pumpAndSettle();
      expect(button(tester).size.height, 45);
      expect(inputHeight(tester), 41);
    }
  });
}

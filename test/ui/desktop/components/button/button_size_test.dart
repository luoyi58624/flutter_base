import 'package:flutter_base/src/ui/desktop/components/icon/index.dart';
import 'package:flutter_base/desktop.dart' hide ElIcon;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 通用主题尺寸档驱动按钮高度：
/// - 默认注入桌面 medium（36）/ 移动 large（40）；
/// - $size 可在祖先覆写，按钮与输入框共享 ElTheme.$controlHeights 五档表。
void main() {
  Widget host(Widget child, {Map<Object, Object>? vars}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElDesktopTheme(
          style: ElStyle(vars: vars),
          child: child,
        ),
      );

  double buttonHeight(WidgetTester tester) => tester
      .renderObject<ElRenderView>(
        find
            .descendant(
              of: find.byType(ElButton),
              matching: find.byType(ElButtonView),
            )
            .first,
      )
      .size
      .height;

  double inputHeight(WidgetTester tester) => tester
      .renderObject<ElRenderView>(
        find
            .descendant(of: find.byType(ElInput), matching: find.byType(ElView))
            .first,
      )
      .size
      .height;

  testWidgets('默认档（桌面宿主 = medium）按钮高 36', (tester) async {
    await tester.pumpWidget(host(ElButton(child: '按钮')));
    await tester.pumpAndSettle();
    expect(buttonHeight(tester), 36);
  });

  testWidgets(r'$size 覆写 small / large 换档：32 / 40', (tester) async {
    await tester.pumpWidget(
      host(
        ElButton(child: '按钮'),
        vars: {ElTheme.$size: ElLevelType.sm},
      ),
    );
    await tester.pumpAndSettle();
    expect(buttonHeight(tester), 32);

    await tester.pumpWidget(
      host(
        ElButton(child: '按钮'),
        vars: {ElTheme.$size: ElLevelType.lg},
      ),
    );
    await tester.pumpAndSettle();
    expect(buttonHeight(tester), 40);
  });

  testWidgets(r'祖先 ElView vars 的 $size 覆写全局档，并同步影响内容 token', (tester) async {
    // 全局 large（40），局部 small（32）；vars 由用户自行嵌套 ElView 传递
    await tester.pumpWidget(
      host(
        ElView(
          style: ElStyle(vars: {ElTheme.$size: ElLevelType.sm}),
          child: ElButton(
            child: '按钮',
            leftIcon: ElIcons.menu,
            rightIcon: ElIcons.arrowRight,
          ),
        ),
        vars: {ElTheme.$size: ElLevelType.lg},
      ),
    );
    await tester.pumpAndSettle();
    expect(buttonHeight(tester), 32);

    final icons = tester
        .widgetList<ElIcon>(
          find.descendant(
            of: find.byType(ElButton),
            matching: find.byType(ElIcon),
          ),
        )
        .toList();
    expect(icons.map((icon) => tester.getSize(find.byWidget(icon))), [
      Size(13, 13),
      Size(13, 13),
    ]);
    final gaps = find.descendant(
      of: find.byType(ElButton),
      matching: find.byWidgetPredicate(
        (widget) => widget is ElView && widget.child == null,
      ),
    );
    expect(
      gaps.evaluate().map(
        (gap) => tester.getSize(find.byWidget(gap.widget)).width,
      ),
      [6.0, 6.0],
    );
  });

  testWidgets(r'按钮与输入框共享 ElTheme.$controlHeights，可由全局表统一覆写', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            ElButton(child: '按钮'),
            ElInput(value: ''),
          ],
        ),
        vars: {
          ElTheme.$size: ElLevelType.sm,
          ElTheme.$controlHeights: [25.0, 33.0, 37.0, 41.0, 45.0],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(buttonHeight(tester), 33);
    expect(inputHeight(tester), 33);

    await tester.pumpWidget(
      host(
        Column(
          children: [
            ElButton(child: '按钮'),
            ElInput(value: ''),
          ],
        ),
        vars: {
          ElTheme.$size: ElLevelType.lg,
          ElTheme.$controlHeights: [25.0, 33.0, 37.0, 41.0, 45.0],
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(buttonHeight(tester), 41);
    expect(inputHeight(tester), 41);
  });
}

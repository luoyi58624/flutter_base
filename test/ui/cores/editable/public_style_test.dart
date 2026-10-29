import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show RenderEditableLine, EditableLineView;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('组合样式沿祖先继承实际文字值、方向和选区，更新不重建编辑子树', (tester) async {
    final controller = ElEditableController(text: 'ab');
    var builds = 0;
    final child = _BuildProbe(
      onBuild: () => builds++,
      child: ElEditableView(controller: controller, style: ElEditableStyle(fixedLineHeight: true)),
    );
    Widget scene(double fontSize, Color color) => Directionality(
      textDirection: .ltr,
      child: ElView(
        style: ElStyle(
          width: 320,
          height: 120,
          fontSize: fontSize,
          color: color,
          fontFamily: 'Ahem',
          fontWeight: .w500,
          lineHeight: 1.5,
          letterSpacing: 1,
          textDirection: .rtl,
          textAlign: .end,
          onSelection: ElStyle(bgColor: Color(0xff223344), color: Color(0xffddeeff)),
        ),
        child: child,
      ),
    );
    await tester.pumpWidget(scene(14, Color(0xff123456)));
    await tester.pumpAndSettle();
    final line = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView));
    final first = line.scope.config;
    expect(first.textStyle.fontSize, 14);
    expect(first.textStyle.fontFamily, 'Ahem');
    expect(first.textStyle.fontWeight, FontWeight.w500);
    expect(first.textStyle.height, 1.5);
    expect(first.textStyle.letterSpacing, 1);
    expect(first.textDirection, TextDirection.rtl);
    expect(first.textAlign, TextAlign.end);
    expect(first.caretColor, Color(0xff123456));
    expect(first.selectionColor, Color(0xff223344));
    expect(first.selectionTextColor, Color(0xffddeeff));
    final height = controller.caretRectGlobal()!.height;
    await tester.pumpWidget(scene(28, Color(0xff654321)));
    await tester.pumpAndSettle();
    expect(builds, 1);
    expect(line.scope.config.textStyle.fontSize, 28);
    expect(line.scope.config.textStyle.color, Color(0xff654321));
    expect(controller.caretRectGlobal()!.height, greaterThan(height * 1.8));
    await tester.pumpWidget(ElView());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('view 的状态颜色覆盖沿用级联，颜色变化不重新排版正文', (tester) async {
    final controller = ElEditableController(text: 'color');
    var builds = 0;
    final child = _BuildProbe(
      onBuild: () => builds++,
      child: ElEditableView(
        controller: controller,
        style: ElEditableStyle(
          view: ElStyle(
            color: Color(0xff123456),
            onDark: ElStyle(color: Color(0xffabcdef)),
          ),
        ),
      ),
    );
    Widget scene(Brightness brightness) => Directionality(
      textDirection: .ltr,
      child: ElView(
        themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
        style: ElStyle(width: 320, height: 120, fontSize: 18, lineHeight: 1.5),
        child: child,
      ),
    );
    await tester.pumpWidget(scene(.light));
    await tester.pumpAndSettle();
    final line = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView));
    final layouts = RenderEditableLine.debugLayoutCount;
    expect(line.scope.config.textStyle.color, Color(0xff123456));
    await tester.pumpWidget(scene(.dark));
    await tester.pumpAndSettle();
    expect(builds, 1);
    expect(RenderEditableLine.debugLayoutCount, layouts);
    expect(line.scope.config.textStyle.color, Color(0xffabcdef));
    expect(line.scope.config.textStyle.fontSize, 18);
    await tester.pumpWidget(ElView());
    await tester.pump();
    controller.dispose();
  });
}

class _BuildProbe extends StatelessWidget {
  const _BuildProbe({required this.onBuild, required this.child});
  final VoidCallback onBuild;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}

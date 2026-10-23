import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/view/render/view.dart';
import 'package:flutter_base/src/ui/view/style/resolved/layout.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('空声明立即拥有引擎，不解析空属性也不创建动画时钟', () {
    final render = ElRenderView(
      const ElStyle(transitions: [ElTransition.all()]),
      TextDirection.ltr,
    );
    final engine = render.styleEngine;
    expect(engine.debugParseCount, 0);
    expect(engine.debugTickerCreated, isFalse);
    expect(
      engine.readLayout(const BoxConstraints(maxWidth: 400), render.boxLayout),
      same(LayoutStyle.empty),
    );
    render.applyStyle(const ElStyle(), textDirection: TextDirection.rtl);
    expect(render.styleEngine, same(engine));
    expect(engine.debugParseCount, 0);
    expect(engine.debugTickerCreated, isFalse);
    render.dispose();
  });

  test('方向变化只重新解析方向性属性', () {
    final render = ElRenderView(
      const ElStyle(
        width: '50%',
        backgroundColor: Color(0xffff0000),
        padding: EdgeInsetsDirectional.only(start: 20),
        margin: EdgeInsets.all(4),
      ),
      TextDirection.ltr,
    );
    final engine = render.styleEngine;
    expect(engine.debugParseCount, 4);
    render.applyStyle(
      const ElStyle(
        width: '50%',
        backgroundColor: Color(0xffff0000),
        padding: EdgeInsetsDirectional.only(start: 20),
        margin: EdgeInsets.all(4),
      ),
      textDirection: TextDirection.rtl,
    );
    expect(engine.debugParseCount, 5);
    final values = engine.readLayout(
      const BoxConstraints(maxWidth: 400),
      render.boxLayout,
    );
    expect(values.width, 196);
    expect(values.padding, const EdgeInsets.only(right: 20));
    expect(values.margin, const EdgeInsets.all(4));
    render.dispose();
  });

  testWidgets('纯颜色更新与动画不重复解析尺寸和边距，宿主保留同一引擎', (tester) async {
    const key = ValueKey('engine');
    Widget scene(Color color, {TextDirection direction = TextDirection.ltr}) =>
        Directionality(
          textDirection: direction,
          child: Center(
            child: ElView(
              key: key,
              style: ElStyle(
                width: '50%',
                height: 40,
                padding: const EdgeInsets.all(4),
                backgroundColor: color,
                transitions: const [
                  ElTransition.all(Duration(milliseconds: 100), Curves.linear),
                ],
              ),
            ),
          ),
        );
    await tester.pumpWidget(scene(const Color(0xffff0000)));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = render.styleEngine;
    final count = engine.debugParseCount;
    expect(engine.debugTickerCreated, isFalse);
    await tester.pumpWidget(scene(const Color(0xff0000ff)));
    expect(engine.debugParseCount, count + 1);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(engine.debugParseCount, count + 1);
    await tester.pumpWidget(
      scene(const Color(0xff0000ff), direction: TextDirection.rtl),
    );
    expect(engine.debugParseCount, count + 1);
    expect(render.styleEngine, same(engine));
    expect(tester.binding.transientCallbackCount, 0);
  });
}

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('普通读者离树时立即释放祖先状态订阅', (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElView(
          style: ElStyle(),
          child: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, shown, _) => shown
                ? Builder(
                    builder: (context) {
                      ElView.of(context).hasHover;
                      return SizedBox(width: 20, height: 20);
                    },
                  )
                : SizedBox.shrink(),
          ),
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(find.byType(ElView));
    final source = render.stateSource;
    expect(source.hasListeners, isTrue);
    visible.value = false;
    await tester.pump();
    expect(source.hasListeners, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GlobalKey 读者迁移后仅订阅新祖先', (tester) async {
    final leftKey = ValueKey('left');
    final rightKey = ValueKey('right');
    bool? value;
    final reader = Builder(
      key: GlobalKey(),
      builder: (context) {
        final style = ElView.of(context);
        value = style.hasHover;
        return SizedBox(width: 10, height: 10);
      },
    );
    Widget tree(bool left) => Directionality(
      textDirection: .ltr,
      child: Row(
        children: [
          for (final side in [true, false])
            Expanded(
              child: ElView(
                key: side ? leftKey : rightKey,
                style: ElStyle(),
                child: side == left ? reader : SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
    await tester.pumpWidget(tree(true));
    final left = tester.renderObject<ElRenderView>(find.byKey(leftKey));
    final right = tester.renderObject<ElRenderView>(find.byKey(rightKey));
    left.setHover(true);
    await tester.pump();
    expect(value, isTrue);
    expect(left.stateSource.hasListeners, isTrue);
    await tester.pumpWidget(tree(false));
    expect(value, isFalse);
    expect(left.stateSource.hasListeners, isFalse);
    expect(right.stateSource.hasListeners, isTrue);
    expect(tester.takeException(), isNull);
  });
}

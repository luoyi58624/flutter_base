import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _first(BuildContext context, ElSwitch component) => ElView(child: 'first');
Widget _second(BuildContext context, ElSwitch component) => ElView(child: 'second');

class _Model extends ValueNotifier<bool> {
  _Model(super.value);
  bool get listening => hasListeners;
}

void main() {
  test('开关主题参与全局合并、替换和相等比较', () {
    final first = _first;
    final global = ElComponentBuilders(switchBuilder: first);
    expect(global.merge(ElComponentBuilders()), global);
    expect(global.copyWith(switchBuilder: null).switchBuilder, isNull);
    final other = global.merge(ElComponentBuilders(switchBuilder: _second));
    expect(other.switchBuilder, _second);
    expect(other, isNot(global));
  });

  testWidgets('公共声明原样交给全局实现，替换实现时不保留旧组件', (tester) async {
    final model = _Model(false);
    addTearDown(model.dispose);
    final declaration = ElSwitch(
      modelValue: model,
      height: 30,
      gap: 3,
      widthAspect: 1.8,
      slide: false,
      activeContent: '开',
      trackStyle: ElStyle(width: 80),
    );
    ElSwitch? received;
    Widget builder(BuildContext context, ElSwitch component) {
      received = component;
      return ElView(child: component.activeContent);
    }

    Widget host(Widget Function(BuildContext, ElSwitch) implementation) => Directionality(
      textDirection: .ltr,
      child: ElComponentProvider(
        builders: ElComponentBuilders(switchBuilder: implementation),
        child: declaration,
      ),
    );
    await tester.pumpWidget(host(builder));
    expect(received, same(declaration));
    expect(model.listening, isFalse, reason: '公共声明不自行持有值绑定');
    await tester.pumpWidget(host(_second));
    expect(tester.widgetList<ElView>(find.byType(ElView)).single.child, 'second');
  });
}

import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _second(BuildContext context, ElSwitch component, Obs<bool> model) => ElView(child: 'second');

void main() {
  testWidgets('公共声明持有模型并交给实现，实现写入后同步外部模型', (tester) async {
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    final changes = <bool>[];
    final declaration = ElSwitch(modelValue: model, onChanged: changes.add);
    ElSwitch? received;
    Obs<bool>? receivedModel;
    Widget builder(BuildContext context, ElSwitch component, Obs<bool> value) {
      received = component;
      receivedModel = value;
      return ElView(child: '${value.value}');
    }

    Widget host(Widget Function(BuildContext, ElSwitch, Obs<bool>) implementation) => Directionality(
      textDirection: .ltr,
      child: ElComponentProvider(
        components: ElComponents(switcher: implementation),
        child: declaration,
      ),
    );
    await tester.pumpWidget(host(builder));
    expect(received, same(declaration));
    receivedModel!.value = true;
    await tester.pump();
    expect(model.value, isTrue);
    expect(changes, [true]);
    expect(tester.widgetList<ElView>(find.byType(ElView)).single.child, 'true');
    await tester.pumpWidget(host(_second));
    expect(tester.widgetList<ElView>(find.byType(ElView)).single.child, 'second');
  });
}

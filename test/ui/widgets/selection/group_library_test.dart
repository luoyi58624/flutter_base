import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/components/checkbox/group.dart' as checks;
import 'package:flutter_base/src/ui/components/radio/group.dart' as radios;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('两个 Group 可从独立库导入并提供上下文，无需品牌 Builder', (tester) async {
    final model = ValueNotifier<List<String>>(['a']);
    addTearDown(model.dispose);
    late checks.ElCheckboxGroupScope checkbox;
    late radios.ElRadioGroupScope radio;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Column(
          mainAxisSize: .min,
          children: [
            checks.ElCheckboxGroup<String>(
              modelValue: model,
              children: [
                Builder(
                  builder: (context) {
                    checkbox = checks.ElCheckboxGroup.maybeOf(context)!;
                    return Text('${checkbox.value}');
                  },
                ),
              ],
            ),
            radios.ElRadioGroup<String>(
              value: 'r',
              children: [
                Builder(
                  builder: (context) {
                    radio = radios.ElRadioGroup.maybeOf(context)!;
                    return Text('${radio.value}');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
    expect(checkbox.value, ['a']);
    expect(radio.value, 'r');
    checkbox.setSelected('b', true);
    await tester.pump();
    expect(model.value, ['a', 'b']);
    expect(checkbox.value, ['a', 'b']);
    await tester.pumpWidget(SizedBox());
  });
}

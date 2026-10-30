import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/widgets/group/checkbox_group.dart' as checks;
import 'package:flutter_base/src/flutter/widgets/group/radio_group.dart' as radios;
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
              child: Builder(
                builder: (context) {
                  checkbox = checks.ElCheckboxGroup.maybeOf(context)!;
                  return Text('${checkbox.modelValue}');
                },
              ),
            ),
            radios.ElRadioGroup<String>(
              value: 'r',
              child: Builder(
                builder: (context) {
                  radio = radios.ElRadioGroup.maybeOf(context)!;
                  return Text('${radio.modelValue}');
                },
              ),
            ),
          ],
        ),
      ),
    );
    expect(checkbox.modelValue, ['a']);
    expect(radio.modelValue, 'r');
    checkbox.addElement('b');
    await tester.pump();
    expect(model.value, ['a', 'b']);
    expect(checkbox.modelValue, ['a', 'b']);
    await tester.pumpWidget(SizedBox());
  });
}

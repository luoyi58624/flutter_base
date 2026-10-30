import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Field extends ElInputModelValue<String> {
  _Field(this.capture);
  final void Function(String value, ValueChanged<String> change) capture;

  @override
  Widget obsBuilder(BuildContext context) {
    capture($obs.value, (value) => $obs.value = value);
    return ElView(child: $obs.value);
  }
}

void main() {
  testWidgets('仅依赖 el_ui 的表单保留类型转换、双向绑定、校验和字段注销', (tester) async {
    final model = ValueNotifier<Map<String, dynamic>>({'name': 42});
    addTearDown(model.dispose);
    late ElFormState form;
    late ValueChanged<String> change;
    String? current;
    Widget scene({bool field = true}) => Directionality(
      textDirection: .ltr,
      child: ElForm(
        modelValue: model,
        rules: {
          'name': [ElRequiredFormRule(message: 'required', trigger: .change)],
        },
        child: Builder(
          builder: (context) {
            form = ElForm.of(context);
            return field
                ? ElFormItem(
                    prop: 'name',
                    label: 'name',
                    child: _Field((value, setter) {
                      current = value;
                      change = setter;
                    }),
                  )
                : ElView();
          },
        ),
      ),
    );
    await tester.pumpWidget(scene());
    expect(current, '42');
    change('Alice');
    await tester.pump();
    expect(model.value['name'], 'Alice');
    model.value = {'name': 'Bob'};
    await tester.pump();
    expect(current, 'Bob');
    change('');
    await tester.pump();
    expect(form.validate(), isFalse);
    expect(form.errorMessages['name'], 'required');
    form.reset();
    await tester.pump();
    expect(model.value['name'], '42', reason: '文本字段回灌后收敛为字符串');
    expect(current, '42');
    await tester.pumpWidget(scene(field: false));
    model.value = {'name': ''};
    expect(form.validate(), isTrue, reason: '卸载字段必须解除注册');
  });
}

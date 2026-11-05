import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _tile<T>(BuildContext context, ElListTile<T> component) => Text('$T|${component.currentValue}');

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElComponentProvider(
    builders: ElComponents(listTile: _tile),
    child: child,
  ),
);

void main() {
  testWidgets('弹窗保留 String 泛型，外部模型更新会重建并通知一次', (tester) async {
    final model = ValueNotifier<String>('alpha');
    addTearDown(model.dispose);
    final changes = <String>[];
    final tile = ElListTile<String>.popup(
      title: '排序方式',
      options: [ElLabelModel('名称', 'alpha'), ElLabelModel('时间', 'beta')],
      modelValue: model,
      onChanged: changes.add,
    );
    await tester.pumpWidget(_host(tile));
    expect(find.text('String|alpha'), findsOneWidget);
    expect(changes, isEmpty);

    model.value = 'beta';
    await tester.pump();
    expect(find.text('String|beta'), findsOneWidget);
    expect(changes, ['beta']);

    model.value = 'beta';
    await tester.pump();
    expect(changes, ['beta']);

    tile.currentValue = 'alpha';
    await tester.pump();
    expect(find.text('String|alpha'), findsOneWidget);
    expect(model.value, 'alpha');
    expect(changes, ['beta', 'alpha']);
  });

  testWidgets('开关保留 bool 泛型，外部模型更新会重建并通知一次', (tester) async {
    final model = ValueNotifier<bool>(false);
    addTearDown(model.dispose);
    final changes = <bool>[];
    await tester.pumpWidget(_host(ElListTile<bool>.switcher(title: '通知', modelValue: model, onChanged: changes.add)));
    expect(find.text('bool|false'), findsOneWidget);
    expect(changes, isEmpty);

    model.value = true;
    await tester.pump();
    expect(find.text('bool|true'), findsOneWidget);
    expect(changes, [true]);

    model.value = true;
    await tester.pump();
    expect(changes, [true]);
  });

  testWidgets('未绑定普通行及未选择的可空弹窗可以挂载', (tester) async {
    await tester.pumpWidget(_host(ElListTile(title: '普通行')));
    expect(find.textContaining(RegExp(r'\|null$')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_host(ElListTile<String?>.popup(title: '尚未选择', options: [ElLabelModel<String?>('不设置')])));
    expect(find.text('String?|null'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      () => ElListTile<String>.popup(title: '非法空选项', value: 'name', options: [ElLabelModel<String>('空值')]),
      throwsAssertionError,
    );
  });

  testWidgets('开关未提供值通道时以 false 初始化', (tester) async {
    final changes = <bool>[];
    final tile = ElListTile<bool>.switcher(title: '通知', onChanged: changes.add);
    await tester.pumpWidget(_host(tile));
    expect(find.text('bool|false'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tile.currentValue = true;
    await tester.pump();
    expect(find.text('bool|true'), findsOneWidget);
    expect(changes, [true]);
  });
}

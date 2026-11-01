import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Preference { system, dark }

class _Choice {
  _Choice(this.id);

  final int id;

  @override
  bool operator ==(Object other) => other is _Choice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'choice:$id';
}

Widget _group<D>(BuildContext context, ElListTileGroup<D> component) =>
    Column(mainAxisSize: .min, children: [Text('$D|${component.currentValue}'), ...component.children]);

Widget _tile<T>(BuildContext context, ElListTile<T> component) => Text('${component.title}');

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: ElComponentProvider(
    builders: ElComponentBuilders(listTileGroupBuilder: _group, listTileBuilder: _tile),
    child: child,
  ),
);

List<ElListTile<_Preference>> _preferences() => [
  ElListTile<_Preference>(value: _Preference.system, title: '跟随系统'),
  ElListTile<_Preference>(value: _Preference.dark, title: '深色'),
];

void main() {
  testWidgets('单选保留枚举可空泛型，内外模型更新各通知一次', (tester) async {
    final model = ValueNotifier<_Preference?>(_Preference.system);
    addTearDown(model.dispose);
    final changes = <_Preference?>[];
    final group = ElListTileGroup<_Preference?>.single(
      modelValue: model,
      onChanged: changes.add,
      children: _preferences(),
    );
    await tester.pumpWidget(_host(group));
    expect(find.text('_Preference?|_Preference.system'), findsOneWidget);
    expect(changes, isEmpty);

    group.currentValue = _Preference.dark;
    await tester.pump();
    expect(find.text('_Preference?|_Preference.dark'), findsOneWidget);
    expect(model.value, _Preference.dark);
    expect(changes, [_Preference.dark]);

    model.value = _Preference.system;
    await tester.pump();
    expect(find.text('_Preference?|_Preference.system'), findsOneWidget);
    expect(changes, [_Preference.dark, _Preference.system]);
    model.value = _Preference.system;
    await tester.pump();
    expect(changes, [_Preference.dark, _Preference.system]);
  });

  testWidgets('多选保留业务对象列表类型，构造和更新不修改原集合', (tester) async {
    final initial = <_Choice>[_Choice(1)];
    final model = ValueNotifier<List<_Choice>>(initial);
    addTearDown(model.dispose);
    final changes = <List<_Choice>>[];
    final group = ElListTileGroup<List<_Choice>>.multi(
      modelValue: model,
      onChanged: changes.add,
      children: [
        ElListTile<_Choice>(value: _Choice(1), title: '第一项'),
        ElListTile<_Choice>(value: _Choice(2), title: '第二项'),
      ],
    );
    expect(model.value, same(initial));
    expect(initial, [_Choice(1)]);
    await tester.pumpWidget(_host(group));
    expect(find.text('List<_Choice>|[choice:1]'), findsOneWidget);

    group.currentValue = <_Choice>[_Choice(2)];
    await tester.pump();
    expect(find.text('List<_Choice>|[choice:2]'), findsOneWidget);
    expect(model.value, isA<List<_Choice>>());
    expect(changes, [
      <_Choice>[_Choice(2)],
    ]);
    expect(initial, [_Choice(1)]);

    model.value = <_Choice>[_Choice(1), _Choice(2)];
    await tester.pump();
    expect(find.text('List<_Choice>|[choice:1, choice:2]'), findsOneWidget);
    expect(changes.length, 2);
    expect(group.currentValue, [_Choice(1), _Choice(2)]);
    expect(initial, [_Choice(1)]);
  });

  testWidgets('普通列表行和未选中的可空单选可直接挂载', (tester) async {
    await tester.pumpWidget(_host(ElListTileGroup(children: [ElListTile(title: '普通内容')])));
    expect(find.text('普通内容'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_host(ElListTileGroup<_Preference?>.single(children: _preferences())));
    expect(find.text('_Preference?|null'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('父级 value 回灌同步当前模型但不回调变化', (tester) async {
    var value = _Preference.system;
    late StateSetter rebuild;
    final changes = <_Preference?>[];
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ElListTileGroup<_Preference?>.single(value: value, onChanged: changes.add, children: _preferences());
          },
        ),
      ),
    );
    expect(find.text('_Preference?|_Preference.system'), findsOneWidget);
    rebuild(() => value = _Preference.dark);
    await tester.pumpAndSettle();
    expect(find.text('_Preference?|_Preference.dark'), findsOneWidget);
    expect(changes, isEmpty);
  });

  test('多选拒绝非列表模型', () {
    expect(() => ElListTileGroup<int>.multi(value: 0, children: []), throwsAssertionError);
  });
}

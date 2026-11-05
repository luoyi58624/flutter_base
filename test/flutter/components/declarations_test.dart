import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _plain(BuildContext context, dynamic component) => SizedBox();

Widget _generic<D>(BuildContext context, dynamic component) => SizedBox();

Widget _listTile<T>(BuildContext context, ElListTile<T> component) => SizedBox();

Widget _listTileGroup<D>(BuildContext context, ElListGroup<D> component) => SizedBox();

void main() {
  test('card 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(card: _plain);
    expect(value.card, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(card: null).card, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('loadingIndicator 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(loadingIndicator: _plain);
    expect(value.loadingIndicator, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(loadingIndicator: null).loadingIndicator, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('listTile 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(listTile: _listTile);
    expect(value.listTile, _listTile);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(listTile: null).listTile, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('listTileGroup 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(listTileGroup: _listTileGroup);
    expect(value.listTileGroup, _listTileGroup);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(listTileGroup: null).listTileGroup, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('steps 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(steps: _plain);
    expect(value.steps, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(steps: null).steps, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('step 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(step: _plain);
    expect(value.step, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(step: null).step, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('avatar 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(avatar: _plain);
    expect(value.avatar, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(avatar: null).avatar, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('calendar 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(calendar: _generic);
    expect(value.calendar, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(calendar: null).calendar, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('collapse 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(collapse: _generic);
    expect(value.collapse, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(collapse: null).collapse, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('collapseItem 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(collapseItem: _generic);
    expect(value.collapseItem, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(collapseItem: null).collapseItem, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('empty 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(empty: _plain);
    expect(value.empty, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(empty: null).empty, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('progress 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(progress: _plain);
    expect(value.progress, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(progress: null).progress, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('segmented 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(segmented: _generic);
    expect(value.segmented, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(segmented: null).segmented, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('slider 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(slider: _generic);
    expect(value.slider, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(slider: null).slider, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('skeleton 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(skeleton: _plain);
    expect(value.skeleton, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(skeleton: null).skeleton, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('tabs 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(tabs: _generic);
    expect(value.tabs, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(tabs: null).tabs, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('tabBar 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(tabBar: _plain);
    expect(value.tabBar, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(tabBar: null).tabBar, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  test('alert 的登记、复制、清空、合并与比较', () {
    final value = ElComponents(alert: _plain);
    expect(value.alert, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(alert: null).alert, isNull);
    expect(ElComponents().merge(value), value);
    expect(value.merge(ElComponents()), value);
    expect(value, isNot(ElComponents()));
  });

  testWidgets('新声明仅分派原始参数，不执行交互或绑定', (tester) async {
    final seen = <Widget>[];
    var closes = 0;
    final alert = ElAlert(title: '提示', onClose: () => closes++);
    final progress = ElProgress(value: 30, max: 60, buffer: 50);
    Widget capture(BuildContext context, dynamic component) {
      seen.add(component as Widget);
      return SizedBox();
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElComponentProvider(
          components: ElComponents(alert: capture, progress: capture),
          child: Column(children: [alert, progress]),
        ),
      ),
    );
    expect(seen, orderedEquals([alert, progress]));
    expect(closes, 0);
    expect(progress.value, 30);
    expect(progress.max, 60);
    expect(progress.buffer, 50);
    await tester.pumpWidget(SizedBox());
  });

  test('布局末项状态允许未提供，不在声明层伪造信息', () {
    expect(ElRadioState(checked: false, disabled: false).isLast, isNull);
    expect(ElCheckboxState(checked: true, disabled: false, isLast: true).isLast, isTrue);
  });
}

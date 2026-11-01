import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _plain(BuildContext context, dynamic component) => SizedBox();

Widget _generic<D>(BuildContext context, dynamic component) => SizedBox();

Widget _listTile<T>(BuildContext context, ElListTile<T> component) => SizedBox();

Widget _listTileGroup<D>(BuildContext context, ElListTileGroup<D> component) => SizedBox();

void main() {
  test('card 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(cardBuilder: _plain);
    expect(value.cardBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(cardBuilder: null).cardBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('loadingIndicator 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(loadingIndicatorBuilder: _plain);
    expect(value.loadingIndicatorBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(loadingIndicatorBuilder: null).loadingIndicatorBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('icon 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(iconBuilder: _plain);
    expect(value.iconBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(iconBuilder: null).iconBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('listTile 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(listTileBuilder: _listTile);
    expect(value.listTileBuilder, _listTile);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(listTileBuilder: null).listTileBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('listTileGroup 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(listTileGroupBuilder: _listTileGroup);
    expect(value.listTileGroupBuilder, _listTileGroup);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(listTileGroupBuilder: null).listTileGroupBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('steps 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(stepsBuilder: _plain);
    expect(value.stepsBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(stepsBuilder: null).stepsBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('step 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(stepBuilder: _plain);
    expect(value.stepBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(stepBuilder: null).stepBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('avatar 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(avatarBuilder: _plain);
    expect(value.avatarBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(avatarBuilder: null).avatarBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('calendar 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(calendarBuilder: _generic);
    expect(value.calendarBuilder, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(calendarBuilder: null).calendarBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('collapse 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(collapseBuilder: _generic);
    expect(value.collapseBuilder, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(collapseBuilder: null).collapseBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('collapseItem 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(collapseItemBuilder: _generic);
    expect(value.collapseItemBuilder, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(collapseItemBuilder: null).collapseItemBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('empty 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(emptyBuilder: _plain);
    expect(value.emptyBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(emptyBuilder: null).emptyBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('progress 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(progressBuilder: _plain);
    expect(value.progressBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(progressBuilder: null).progressBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('segmented 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(segmentedBuilder: _generic);
    expect(value.segmentedBuilder, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(segmentedBuilder: null).segmentedBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('slider 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(sliderBuilder: _generic);
    expect(value.sliderBuilder, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(sliderBuilder: null).sliderBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('skeleton 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(skeletonBuilder: _plain);
    expect(value.skeletonBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(skeletonBuilder: null).skeletonBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('tabs 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(tabsBuilder: _generic);
    expect(value.tabsBuilder, _generic);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(tabsBuilder: null).tabsBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('tabBar 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(tabBarBuilder: _plain);
    expect(value.tabBarBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(tabBarBuilder: null).tabBarBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
  });

  test('alert 的登记、复制、清空、合并与比较', () {
    final value = ElComponentBuilders(alertBuilder: _plain);
    expect(value.alertBuilder, _plain);
    expect(value.copyWith(), value);
    expect(value.copyWith().hashCode, value.hashCode);
    expect(value.copyWith(alertBuilder: null).alertBuilder, isNull);
    expect(ElComponentBuilders().merge(value), value);
    expect(value.merge(ElComponentBuilders()), value);
    expect(value, isNot(ElComponentBuilders()));
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
          builders: ElComponentBuilders(alertBuilder: capture, progressBuilder: capture),
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

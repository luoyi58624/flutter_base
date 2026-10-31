import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **ElButtonGroup 单选 / 多选行为锁**：
/// - 受控三通道（value 自持 / modelValue 双向 / prop 表单），值默认 = 子项
///   下标，可用 [ElButtonGroupItem.value] 自定义
/// - single：点击已选中项清空（回调 null，需可空泛型），mandatory 时静默
/// - multi：List / Set 集合进出类型一致，mandatory 时不允许清最后一项
/// - 选中项由组件选择普通样式，子项原 onPressed 在切换后照常触发
void main() {
  Widget host(Widget group) => MediaQuery(
    data: const MediaQueryData(size: Size(600, 300)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ElDesktopTheme(child: Center(child: group)),
    ),
  );

  ElRenderView itemAt(WidgetTester tester, int index) => tester
      .renderObjectList<ElRenderView>(find.byType(ElButtonView))
      .elementAt(index);

  ResolvedStyle committed(WidgetTester tester, int index) =>
      itemAt(tester, index).committedResolvedStyle;

  Future<void> tapItem(WidgetTester tester, int index) async {
    final view = itemAt(tester, index);
    await tester.tapAt(view.localToGlobal(view.size.center(Offset.zero)));
    await tester.pumpAndSettle();
  }

  testWidgets('single：点击选中 → 回调值；再点已选中 → 回调 null；mandatory 静默', (tester) async {
    final changes = <Object?>[];
    Object? model;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => host(
          ElButtonGroup<Object?>.single(
            value: model,
            onChanged: (v) {
              changes.add(v);
              setState(() => model = v);
            },
            children: const [
              ElButtonGroupItem(child: '日'),
              ElButtonGroupItem(child: '周'),
              ElButtonGroupItem(child: '月'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapItem(tester, 1);
    expect(changes, [1], reason: '默认值 = 子项下标');

    await tapItem(tester, 1);
    expect(changes, [1, null], reason: '非 mandatory 点击已选中项清空');

    // mandatory：点击已选中项不回调
    changes.clear();
    model = 2;
    await tester.pumpWidget(
      host(
        ElButtonGroup<Object?>.single(
          value: model,
          mandatory: true,
          onChanged: changes.add,
          children: const [
            ElButtonGroupItem(child: '日'),
            ElButtonGroupItem(child: '周'),
            ElButtonGroupItem(child: '月'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapItem(tester, 2);
    expect(changes, isEmpty, reason: 'mandatory 下点击已选中项静默');
  });

  testWidgets('single：非空泛型下点击已选中项静默，不崩溃', (tester) async {
    // Obs<int> 这类非空泛型写不进 null——清空退化为静默保持，而不是类型崩溃
    final changes = <int>[];
    await tester.pumpWidget(
      host(
        ElButtonGroup<int>.single(
          value: 1,
          onChanged: changes.add,
          children: const [
            ElButtonGroupItem(child: 'A'),
            ElButtonGroupItem(child: 'B'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapItem(tester, 1);
    expect(tester.takeException(), isNull, reason: '非空泛型清空不得抛类型错误');
    expect(changes, isEmpty, reason: '写不进 null → 静默保持选中');
  });

  testWidgets('single：Item.value 自定义值；选中项套 active 配色', (tester) async {
    final changes = <Object?>[];
    await tester.pumpWidget(
      host(
        ElButtonGroup<Object?>.single(
          value: 'week',
          onChanged: changes.add,
          children: const [
            ElButtonGroupItem(value: 'day', child: '日'),
            ElButtonGroupItem(value: 'week', child: '周'),
            ElButtonGroupItem(value: 'month', child: '月'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // value='week' → 第二项选中：default 变体 active = primary 字 + light-9 底
    const primary = Color(0xff409eff);
    const light9 = Color(0xffecf5ff);
    final selectedBox = committed(tester, 1);
    expect(selectedBox.inheritedText.color, isSameColorAs(primary));
    expect(selectedBox.box.backgroundColor, isSameColorAs(light9));
    expect(
      committed(tester, 0).box.backgroundColor,
      isSameColorAs(const Color(0xffffffff)),
      reason: '未选中项保持常态',
    );

    await tapItem(tester, 0);
    expect(changes, ['day'], reason: '自定义 value 生效');
  });

  testWidgets('multi：List 进出、mandatory 保底、原 onPressed 照常触发', (tester) async {
    final changes = <List<Object?>>[];
    var pressed = 0;
    List<Object?> model = [0];
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => host(
          ElButtonGroup<List<Object?>>.multi(
            value: model,
            mandatory: true,
            onChanged: (v) {
              changes.add(v);
              setState(() => model = v);
            },
            children: [
              const ElButtonGroupItem(child: '加粗'),
              ElButtonGroupItem(onPressed: () => pressed++, child: '斜体'),
              const ElButtonGroupItem(child: '下划线'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapItem(tester, 1);
    expect(changes.single, [0, 1]);
    expect(changes.single, isA<List>());
    expect(pressed, 1, reason: '切换选择后原 onPressed 照常触发');

    await tapItem(tester, 0);
    expect(changes.last, [1]);

    // 只剩一个选中 + mandatory → 静默
    await tapItem(tester, 1);
    expect(changes.length, 2, reason: 'mandatory 不允许清最后一项');
  });

  testWidgets('multi：Set 类型保持原样回传', (tester) async {
    final changes = <Set<Object?>>[];
    await tester.pumpWidget(
      host(
        ElButtonGroup<Set<Object?>>.multi(
          value: const {0},
          onChanged: changes.add,
          children: const [
            ElButtonGroupItem(child: 'A'),
            ElButtonGroupItem(child: 'B'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapItem(tester, 1);
    expect(changes.single, isA<Set>());
    expect(changes.single, {0, 1});
  });

  testWidgets('Obs 双向绑定：组内切换回写 Obs、外部改值组自动刷新，全程零 setState', (tester) async {
    const primary = Color(0xff409eff);
    const light9 = Color(0xffecf5ff);
    final period = Obs<Object?>('week');
    addTearDown(period.dispose);

    // 无 StatefulBuilder / setState：刷新完全依赖双向绑定
    await tester.pumpWidget(
      host(
        ElButtonGroup<Object?>.single(
          modelValue: period,
          children: const [
            ElButtonGroupItem(value: 'day', child: '日'),
            ElButtonGroupItem(value: 'week', child: '周'),
            ElButtonGroupItem(value: 'month', child: '月'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      committed(tester, 1).box.backgroundColor,
      isSameColorAs(light9),
      reason: '初始 Obs 值选中周',
    );

    // 组内 → 外：点击月，Obs 被回写
    await tapItem(tester, 2);
    expect(period.value, 'month', reason: '组内切换必须回写外部 Obs');
    expect(committed(tester, 2).box.backgroundColor, isSameColorAs(light9));
    expect(
      committed(tester, 1).box.backgroundColor,
      isSameColorAs(const Color(0xffffffff)),
    );

    // 外 → 组内：程序改 Obs，组视觉自动跟随
    period.value = 'day';
    await tester.pumpAndSettle();
    expect(
      committed(tester, 0).box.backgroundColor,
      isSameColorAs(light9),
      reason: '外部改 Obs 组必须自动刷新',
    );
    expect(committed(tester, 0).inheritedText.color, isSameColorAs(primary));
    expect(
      committed(tester, 2).box.backgroundColor,
      isSameColorAs(const Color(0xffffffff)),
    );
  });

  testWidgets('主题单选：未选中为默认外观，选中使用主题背景、边框及对比文字', (tester) async {
    await tester.pumpWidget(
      host(
        ElButtonGroup<Object?>.single(
          value: 1,
          onChanged: (_) {},
          type: .primary,
          children: const [
            ElButtonGroupItem(child: 'A'),
            ElButtonGroupItem(child: 'B'),
            ElButtonGroupItem(child: 'C'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    const primary = Color(0xff409eff);
    expect(
      committed(tester, 0).box.backgroundColor,
      isSameColorAs(const Color(0xffffffff)),
    );
    expect(
      committed(tester, 0).box.border?.borderTop.borderColor,
      isSameColorAs(const Color(0xffdcdfe6)),
    );
    expect(committed(tester, 1).box.backgroundColor, isSameColorAs(primary));
    expect(committed(tester, 1).box.border?.borderTop.borderColor, isSameColorAs(primary));
    expect(
      committed(tester, 1).inheritedText.color,
      isSameColorAs(Color(0xffffffff)),
    );
  });
}

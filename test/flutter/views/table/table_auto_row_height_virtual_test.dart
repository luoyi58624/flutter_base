// autoRowHeight（动态行高）与列虚拟化的互斥契约。
//
// 列虚拟化按横向窗口挂载列，行高必须由外部给定；动态行高靠全列实测得出 ——
// 两者不可能同时成立。列虚拟化恒开，唯一例外是动态行高：生效皮肤
// `autoRowHeight` 为真时底层自动避让（退化为稠密行），本帧不做列虚拟化。
//
// 背景缺陷：`autoRowHeight: true` + 任一带 slotBuilder（element 单元格）的列
// 会让数据行走「稀疏混合托管」这条懒建路径，而该路径要求定高，于是挂载即命中
// 行原语的深层断言（`cellBuilder == null || rowHeight != null`）。
import 'package:flutter_base/src/flutter/views/table/table.dart';
import 'package:flutter_base/src/flutter/views/view/render/render_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 动态行高皮肤：rowHeight 退化为最小高度。
class _AutoHeightTableStyle extends ElTableStyle {
  const _AutoHeightTableStyle();

  @override
  bool get autoRowHeight => true;

  @override
  double get rowHeight => 30;
}

/// 定高皮肤（对照组）：行高恒为 rowHeight。
class _FixedHeightTableStyle extends ElTableStyle {
  const _FixedHeightTableStyle();

  @override
  double get rowHeight => 30;
}

const String _longText = '这是一段需要在窄列中自动换行并撑高表格行的内容，用来验证动态行高按全列实测';

/// 遍历表格渲染树，按视觉序（dy 升序）收集内容为 [value] 的单元格 render。
List<ElRenderView> _contentRenders(WidgetTester tester, Object value) {
  final root = tester.renderObject<RenderObject>(find.byType(ElTable));
  final nodes = <RenderObject>[root];
  final found = <ElRenderView>[];
  while (nodes.isNotEmpty) {
    final node = nodes.removeLast();
    if (node is ElRenderView && node.rawChild == value) found.add(node);
    node.visitChildren(nodes.add);
  }
  found.sort((a, b) => a.localToGlobal(Offset.zero).dy.compareTo(b.localToGlobal(Offset.zero).dy));
  return found;
}

/// 第 [index] 行（视觉序）的单元格 render——同一文本出现在多行时按 dy 取。
ElRenderView _contentRenderAt(WidgetTester tester, Object value, int index) => _contentRenders(tester, value)[index];

/// 相邻两行同一列内容顶边的纵向间距 = 上一行的行高（两行单元格形状一致，居中偏移抵消）。
double _rowGap(WidgetTester tester, Object value) =>
    _contentRenderAt(tester, value, 1).localToGlobal(Offset.zero).dy -
    _contentRenderAt(tester, value, 0).localToGlobal(Offset.zero).dy;

/// 统计已挂载的 slot 单元格数（渲染树里的 ElRenderView 数量 = 挂载集大小）。
int _slotCellCount(WidgetTester tester) {
  final root = tester.renderObject<RenderObject>(find.byType(ElTable));
  final nodes = <RenderObject>[root];
  var count = 0;
  while (nodes.isNotEmpty) {
    final node = nodes.removeLast();
    if (node is ElRenderView && node.rawChild is String && (node.rawChild! as String).startsWith('slot-')) count++;
    node.visitChildren(nodes.add);
  }
  return count;
}

/// 两行数据、一列普通 slot + 一列换行撑高的 slot。
ElTableController _tallSlotController({int rows = 2}) => ElTableController(
  rowKey: 'id',
  data: [
    for (var index = 0; index < rows; index++) {'id': index},
  ],
  columns: const [
    ElTableColumn(key: 'a', title: 'A', width: 120, slotBuilder: _slot),
    ElTableColumn(key: 'b', title: 'B', width: 120, slotBuilder: _tallSlot),
  ],
);

/// 宽表：30 个 slotBuilder 列 + 3 行。
ElTableController _wideSlotController() => ElTableController(
  rowKey: 'id',
  data: [
    for (var index = 0; index < 3; index++) {'id': index},
  ],
  columns: [
    for (var index = 0; index < 30; index++)
      ElTableColumn(
        key: 'c$index',
        title: 'C$index',
        width: 120,
        slotBuilder: (context, cell) => 'slot-${cell.rowIndex}-$index',
      ),
  ],
);

void main() {
  Widget shell(Widget child, {double width = 500, double height = 400}) => Directionality(
    textDirection: .ltr,
    child: Align(
      alignment: .topLeft,
      child: SizedBox(width: width, height: height, child: child),
    ),
  );

  testWidgets('autoRowHeight + slotBuilder 列：不抛异常且行高按窄列换行内容实测', (tester) async {
    final controller = _tallSlotController();
    addTearDown(controller.dispose);

    // 列虚拟化恒开，本用例的判别力来自「动态行高这一支必须避让」。
    await tester.pumpWidget(shell(ElTable(controller: controller, style: const _AutoHeightTableStyle())));

    expect(tester.takeException(), isNull, reason: 'autoRowHeight 与列虚拟化互斥，auto 应避让而不是撞行原语的深层断言。');
    final tall = _contentRenderAt(tester, _longText, 0);
    expect(tall.size.height, greaterThan(30), reason: '窄列里的长文本应换行撑高单元格。');
    expect(_rowGap(tester, _longText), greaterThanOrEqualTo(tall.size.height), reason: '动态行高按最高的元格实测，后续行被撑开的内容推下去。');
  });

  testWidgets('autoRowHeight + slotBuilder 列：整行走稠密 children（全列挂载）', (tester) async {
    final autoController = _wideSlotController();
    addTearDown(autoController.dispose);
    await tester.pumpWidget(shell(ElTable(controller: autoController, style: const _AutoHeightTableStyle())));

    expect(tester.takeException(), isNull);
    expect(_slotCellCount(tester), 90, reason: '动态行高没有横向窗口：30 列 × 3 行全部挂载（稠密 children）。');

    // 对照组：定高（不避让）时列虚拟化恒开，仍然只挂载横向窗口内的列（列虚拟化本身零回归）。
    final virtualController = _wideSlotController();
    addTearDown(virtualController.dispose);
    await tester.pumpWidget(shell(ElTable(controller: virtualController, style: const _FixedHeightTableStyle())));
    expect(tester.takeException(), isNull);
    expect(_slotCellCount(tester), lessThan(90), reason: '定高时不避让，列虚拟化只挂载窗口内的列。');
  });

  testWidgets('定高 + slotBuilder 列：行高恒为 rowHeight，非 autoRowHeight 行为不变', (tester) async {
    final controller = _tallSlotController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, style: const _FixedHeightTableStyle())));

    expect(tester.takeException(), isNull);
    expect(_rowGap(tester, _longText), closeTo(30, 0.01), reason: '定高行的行高仍由 style.rowHeight 决定，不被内容撑开。');
  });

  testWidgets('autoRowHeight + slotBuilder 列 + 定高视口：行虚拟化恒开也不要求定高', (tester) async {
    final controller = _tallSlotController(rows: 8);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(ElTable(controller: controller, style: const _AutoHeightTableStyle(), height: 240)),
    );

    expect(tester.takeException(), isNull);
    expect(
      _rowGap(tester, _longText),
      greaterThanOrEqualTo(_contentRenderAt(tester, _longText, 0).size.height),
      reason: '行虚拟化的窗口是行维度，不约束行高。',
    );
  });
}

Object? _slot(BuildContext context, ElTableCell cell) => 'slot-${cell.rowIndex}-0';

Object? _tallSlot(BuildContext context, ElTableCell cell) => _longText;

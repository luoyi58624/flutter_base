import 'package:flutter_base/src/ui/cores/selection/docs/selection_view.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show RenderSelectionView, RenderScrollViewportBase;
import 'package:flutter_base/src/ui/cores/selection/common/selection_core.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _tableKey = ValueKey<String>('repro-table-page');
const _otherPageKey = ValueKey<String>('repro-other-page');
const _tableMenuKey = ValueKey<String>('repro-menu-table');
const _otherMenuKey = ValueKey<String>('repro-menu-other');

void main() {
  testWidgets(
    '切页再回表格后可重新选择和滚动当前挂载内容',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1.75
        ..physicalSize = const Size(2100, 1225);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const _SelectionSwitchHarness());
      await tester.pumpAndSettle();

      for (var cycle = 0; cycle < 3; cycle++) {
        final selected = await _dragSelect(tester);
        expect(selected, isTrue, reason: '第 ${cycle + 1} 轮必须先建立跨行跨列选区');
        debugPrint(_selectionSummary(tester, 'before-switch'));

        await tester.tap(find.byKey(_otherMenuKey));
        await tester.pumpAndSettle();
        expect(find.byKey(_tableKey), findsNothing);
        expect(find.byKey(_otherPageKey), findsOneWidget);

        await tester.tap(find.byKey(_tableMenuKey));
        await tester.pumpAndSettle();
        expect(find.byKey(_tableKey), findsOneWidget);
        debugPrint(_selectionSummary(tester, 'after-return'));

        final participants = selectionParticipantsOf(tester.allRenderObjects).toList();
        final ranges = participants.map((participant) => participant.currentSelectionRange).toList();
        expect(
          participants.map((participant) => participant.currentSelectionRange).toList(),
          ranges,
          reason: '绘制前读取参与者范围不应改变选区',
        );
        await _scrollTable(tester, pointerId: 20 + cycle * 2);

        final reselected = await _dragSelect(tester);
        expect(reselected, isTrue, reason: '第 ${cycle + 1} 轮重新选中必须重建活的端点');
        await _scrollTable(tester, pointerId: 21 + cycle * 2);
      }

      expect(tester.takeException(), isNull);
    },
  );
}

List<RenderSelectionView> _selectionRoots(WidgetTester tester) =>
    tester.allRenderObjects.whereType<RenderSelectionView>().toSet().toList();

String _selectionSummary(WidgetTester tester, String phase) =>
    '[el-ui-table-selection] $phase roots=${_selectionRoots(tester).length} '
    'selected=${selectionParticipantsOf(tester.allRenderObjects).where((participant) => participant.currentSelectionRange?.isCollapsed == false).length}';

Rect _visibleRow(WidgetTester tester) {
  final table = tester.getRect(find.byKey(_tableKey));
  final viewport = table.intersect(Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio));
  final rows = find.byWidgetPredicate((widget) => widget.runtimeType.toString().contains('TableRowView'));
  for (var index = 0; index < rows.evaluate().length; index++) {
    final rect = tester.getRect(rows.at(index));
    if (rect.height > 0 && viewport.contains(rect.center)) return rect;
  }
  throw TestFailure('没有找到当前可见表格行：table=$table viewport=$viewport');
}

Future<bool> _dragSelect(WidgetTester tester) async {
  final table = tester.getRect(find.byKey(_tableKey));
  final row = _visibleRow(tester);
  final start = Offset((row.left + 80).clamp(table.left + 8, table.right - 8).toDouble(), row.center.dy);
  final end = Offset(
    (start.dx + 360).clamp(start.dx + 24, table.right - 8).toDouble(),
    (start.dy + row.height * 3).clamp(start.dy + row.height, table.bottom - 8).toDouble(),
  );
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  try {
    await gesture.down(start);
    await tester.pump();
    for (final point in <Offset>[
      Offset(start.dx + (end.dx - start.dx) * 0.35, start.dy),
      Offset(start.dx + (end.dx - start.dx) * 0.7, start.dy + (end.dy - start.dy) * 0.35),
      Offset(end.dx, start.dy + (end.dy - start.dy) * 0.7),
      end,
    ]) {
      await gesture.moveTo(point);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
  } finally {
    await gesture.removePointer();
  }
  final selected = selectionParticipantsOf(tester.allRenderObjects).where((participant) {
    final range = participant.currentSelectionRange;
    return range != null && !range.isCollapsed && participant.value.selectionRects.isNotEmpty;
  }).firstOrNull;
  if (selected == null) return false;
  expect(selected.box, paints..rect(color: selected.effectiveSelectionBgColor));
  return true;
}

Future<void> _scrollTable(WidgetTester tester, {required int pointerId}) async {
  final point = tester.getRect(find.byKey(_tableKey)).center;
  double scrollPixels() => tester.allRenderObjects
      .whereType<RenderScrollViewportBase>()
      .where((viewport) => viewport.axis == Axis.vertical)
      .fold<double>(0, (total, viewport) => total + viewport.position.pixels);
  final initialPixels = scrollPixels();
  final pointer = TestPointer(pointerId, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.addPointer(location: point));
  await tester.sendEventToBinding(pointer.hover(point));
  await tester.pump();
  for (var frame = 0; frame < 20; frame++) {
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 60)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.sendEventToBinding(pointer.removePointer());
  expect(scrollPixels(), greaterThan(initialPixels), reason: '滚轮对照必须实际向下移动，不能在顶部空转');
}

class _SelectionSwitchHarness extends StatefulWidget {
  const _SelectionSwitchHarness();

  @override
  State<_SelectionSwitchHarness> createState() => _SelectionSwitchHarnessState();
}

class _SelectionSwitchHarnessState extends State<_SelectionSwitchHarness> {
  bool _showTable = true;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 1200,
      height: 700,
      child: SelectionView(
        controls: const DesktopSelectionControls(clearOnTapOutside: false),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 160,
              child: Column(
                children: [
                  ElButtonView(
                    key: _tableMenuKey,
                    selected: _showTable,
                    onPressed: () => setState(() => _showTable = true),
                    event: ElEvent(onPointerDown: (event) => event.stopPropagation()),
                    child: 'Table',
                  ),
                  ElButtonView(
                    key: _otherMenuKey,
                    selected: !_showTable,
                    onPressed: () => setState(() => _showTable = false),
                    event: ElEvent(onPointerDown: (event) => event.stopPropagation()),
                    child: 'Other',
                  ),
                ],
              ),
            ),
            Expanded(
              child: _showTable ? const _TablePage(key: _tableKey) : const _OtherPage(key: _otherPageKey),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OtherPage extends StatelessWidget {
  const _OtherPage({super.key});

  @override
  Widget build(BuildContext context) => const ElView(child: 'Other page');
}

class _TablePage extends StatefulWidget {
  const _TablePage({super.key});

  @override
  State<_TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<_TablePage> {
  late final ElTableController _controller = ElTableController(
    rowKey: 'id',
    pinnedRowKeys: const [0],
    data: [
      for (var row = 0; row < 10000; row++)
        {
          'id': row,
          'name': '员工 ${row + 1}',
          for (var column = 1; column <= 10; column++) 'm$column': row * 17 + column * 31,
        },
    ],
    columns: [
      const ElTableColumn(type: .index, width: 64, fixed: .left),
      const ElTableColumn(title: '姓名', prop: 'name', width: 140, fixed: .left),
      for (var column = 1; column <= 9; column++) ElTableColumn(title: '$column 月', prop: 'm$column', width: 100),
      const ElTableColumn(title: '合计', prop: 'm10', width: 110, fixed: .right),
    ],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ElView(child: '10000-row virtual table'),
      Expanded(child: ElTable(controller: _controller, height: 620)),
    ],
  );
}

import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _AutoHeightTableStyle extends ElTableStyle {
  const _AutoHeightTableStyle();

  @override
  bool get autoRowHeight => true;

  @override
  double get rowHeight => 30;
}

/// 皮肤声明斑马纹：奇数展示序号行叠加底色（与 `ElTableStyle.stripe / stripeRow` 同一入口）。
class _SkinHookTableStyle extends ElTableStyle {
  const _SkinHookTableStyle()
    : super(columnResizable: true, stripe: true, stripeRow: const ElStyle(bgColor: Color(0xff123456)));
}

class _FixedDividerTableStyle extends ElTableStyle {
  const _FixedDividerTableStyle();

  @override
  ElStyle get table => const ElStyle(bgColor: Color(0xffffffff));

  @override
  ElStyle get header => const ElStyle(bgColor: Color(0xffffffff));

  @override
  ElStyle get row => const ElStyle(bgColor: Color(0xffffffff));

  @override
  ElStyle get cell => const ElStyle(
    border: .only(left: ElBorderSide(color: Color(0xffff0000))),
  );

  @override
  ElStyle get headerCell => cell;

  @override
  Color get fixedDividerColor => const Color(0xff0000ff);
}

class _DragHeaderSurfaceTableStyle extends ElTableStyle {
  const _DragHeaderSurfaceTableStyle();

  @override
  ElStyle get header => const ElStyle(bgColor: Color(0xffdcecff));

  @override
  ElStyle get headerCell => const ElStyle(
    border: .only(left: ElBorderSide(color: Color(0xff99aabb))),
  );
}

/// 组件主题登记的品牌皮肤：只换样式对象，不接管任何表格实现。
class _ThemeTableStyle extends ElTableStyle {
  const _ThemeTableStyle();

  @override
  double get rowHeight => 24;

  @override
  double get minColumnWidth => 60;
}

/// 主题预设的工厂形态（与 `ElComponentBuilders.tableStyleBuilder` 同签名）。
ElTableStyle _themeTableStyleOf(BuildContext context) => const _ThemeTableStyle();

/// 显式传入的皮肤：必须压过组件主题登记的品牌预设。
class _ExplicitTableStyle extends ElTableStyle {
  const _ExplicitTableStyle();

  @override
  double get rowHeight => 32;

  @override
  double get minColumnWidth => 100;
}

/// 只改空态高度，用于验证 `ElTableStyle.empty` / `emptyHeight` 仍是空态外观的入口。
class _EmptyHeightTableStyle extends ElTableStyle {
  const _EmptyHeightTableStyle();

  @override
  double? get emptyHeight => 120;
}

void main() {
  Iterable<ElRenderView> contentRenders(WidgetTester tester, bool Function(Object? value) matches) sync* {
    final root = tester.renderObject<RenderObject>(find.byType(ElTable));
    final nodes = <RenderObject>[root];
    while (nodes.isNotEmpty) {
      final node = nodes.removeLast();
      if (node is ElRenderView && matches(node.rawChild)) yield node;
      node.visitChildren(nodes.add);
    }
  }

  ElRenderView contentRender(WidgetTester tester, Object value) =>
      contentRenders(tester, (child) => child == value).single;

  Iterable<RenderOrdinalGutter> ordinalRenders(WidgetTester tester, Object value) sync* {
    final root = tester.renderObject<RenderObject>(find.byType(ElTable));
    final nodes = <RenderObject>[root];
    while (nodes.isNotEmpty) {
      final node = nodes.removeLast();
      if (node is RenderOrdinalGutter && node.debugPaintEntries.any((entry) => entry.label == '$value')) {
        yield node;
      }
      node.visitChildren(nodes.add);
    }
  }

  RenderOrdinalGutter ordinalRender(WidgetTester tester, Object value) => ordinalRenders(tester, value).single;

  Offset contentTopLeft(WidgetTester tester, Object value) => contentRender(tester, value).localToGlobal(Offset.zero);

  Future<void> tapContent(WidgetTester tester, Object value) {
    final render = contentRender(tester, value);
    return tester.tapAt(render.localToGlobal(render.size.center(Offset.zero)));
  }

  bool hasSemanticsLabel(WidgetTester tester, String value) {
    var found = false;
    void visit(SemanticsNode node) {
      if (node.label.contains(value)) found = true;
      node.visitChildren((child) {
        visit(child);
        return !found;
      });
    }

    // ignore: deprecated_member_use
    visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    return found;
  }

  Widget shell(Widget child, {double width = 420, double height = 260}) => Directionality(
    textDirection: .ltr,
    child: Align(
      alignment: .topLeft,
      child: SizedBox(width: width, height: height, child: child),
    ),
  );

  /// 不施加约束地看表格的自然几何（列宽计划 + 行高），与 style 断言配套使用。
  Widget bareHost(Widget child) => Directionality(
    textDirection: .ltr,
    child: UnconstrainedBox(alignment: .topLeft, child: child),
  );

  testWidgets('序号列两种托管路径保留单元格样式，数字右对齐并整体居中', (tester) async {
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ElTableController(
      data: [
        for (var i = 0; i < 12; i++) {'name': 'row $i'},
      ],
      columns: [
        ElTableColumn(type: .index, index: 9),
        ElTableColumn(prop: 'name'),
      ],
    );
    addTearDown(controller.dispose);
    addTearDown(() => tester.pumpWidget(SizedBox.shrink()));
    for (final interactive in [false, true]) {
      Future<void> pump(TextAlign align) async {
        controller.columns = [
          ElTableColumn(type: .index, index: 9, indexTextAlign: align),
          ElTableColumn(prop: 'name'),
        ];
        await tester.pumpWidget(
          shell(
            ElTable(
              controller: controller,
              height: 240,
              style: ElTableStyle(cell: ElStyle(bgColor: Color(0xffabcdef))),
              onCellTap: interactive ? (_) {} : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Rect bounds(int number) {
        final render = ordinalRender(tester, number);
        return render.debugPaintEntries.single.textBounds!.shift(render.localToGlobal(Offset.zero));
      }

      await pump(.right);
      final render = ordinalRender(tester, 10);
      final cell = render.parent! as ElRenderView;
      final cellRect = cell.localToGlobal(Offset.zero) & cell.size;
      expect(cell.style?.bgColor, Color(0xffabcdef));
      expect(bounds(10).center.dx, closeTo(cellRect.center.dx, .001));
      expect(bounds(10).left - cellRect.left, closeTo(12, .001));
      expect(cellRect.right - bounds(10).right, closeTo(12, .001));
      expect(bounds(9).right, closeTo(bounds(10).right, .001));
      final width = controller.columnWidthOf(controller.columns.first);
      await pump(.left);
      expect(bounds(9).left, closeTo(bounds(10).left, .001));
      await pump(.center);
      expect(bounds(9).center.dx, closeTo(bounds(10).center.dx, .001));
      expect(controller.columnWidthOf(controller.columns.first), width);
    }
  });

  testWidgets('列数不变时普通列与行号列可以双向切换', (tester) async {
    final controller = ElTableController(
      data: [
        {'name': 'Alice'},
      ],
      columns: [ElTableColumn(key: 'value', prop: 'name')],
    );
    addTearDown(controller.dispose);
    addTearDown(() => tester.pumpWidget(SizedBox.shrink()));
    await tester.pumpWidget(shell(ElTable(controller: controller)));
    expect(contentRenders(tester, (value) => value == 'Alice'), hasLength(1));
    controller.columns = [ElTableColumn(key: 'value', type: .index)];
    await tester.pumpAndSettle();
    expect(ordinalRenders(tester, 1), hasLength(1));
    expect(contentRenders(tester, (value) => value == 'Alice'), isEmpty);
    controller.columns = [ElTableColumn(key: 'value', prop: 'name')];
    await tester.pumpAndSettle();
    expect(ordinalRenders(tester, 1), isEmpty);
    expect(contentRenders(tester, (value) => value == 'Alice'), hasLength(1));
  });

  testWidgets('分页序号在窄表内仍完整单行显示，切换起始值后同步列宽', (tester) async {
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ElTableController(
      data: [
        {'name': 'Alice'},
        {'name': 'Bob'},
      ],
      columns: [
        ElTableColumn(type: .index, index: 101),
        ElTableColumn(title: '姓名', prop: 'name'),
      ],
    );
    addTearDown(controller.dispose);
    addTearDown(() => tester.pumpWidget(SizedBox.shrink()));
    await tester.pumpWidget(shell(ElTable(controller: controller), width: 220));

    void expectSingleLine(int value) {
      final render = ordinalRender(tester, value);
      expect(render.debugPaintEntries.single.label, '$value');
      expect(render.size.width, greaterThan(0));
    }

    expectSingleLine(101);
    expectSingleLine(102);
    final initialWidth = controller.columnWidthOf(controller.columns.first)!;
    controller.columns = [ElTableColumn(type: .index, index: 1001), ElTableColumn(title: '姓名', prop: 'name')];
    await tester.pump();
    expect(controller.columnWidthOf(controller.columns.first), greaterThan(initialWidth));
    expectSingleLine(1001);
    expectSingleLine(1002);
    expect(tester.takeException(), isNull);
  });

  testWidgets('内置列忽略声明与缓存宽度，万行固定序号仍完整单行显示', (tester) async {
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ElTableController(
      rowKey: 'id',
      pinnedRowKeys: [0],
      data: [
        {'id': 0, 'name': '员工 1'},
      ],
      columnWidths: {'index': 18, 'checkbox': 200, 'name': 140},
      columns: [
        ElTableColumn(key: 'index', type: .index, width: 64, minWidth: 200, flex: 10, fixed: .left, resizable: true),
        ElTableColumn(key: 'checkbox', type: .checkbox, width: 12, fixed: .left, resizable: true),
        ElTableColumn(prop: 'name', title: '姓名', width: 120),
      ],
    );
    addTearDown(controller.dispose);
    addTearDown(() => tester.pumpWidget(SizedBox.shrink()));
    await tester.pumpWidget(shell(ElTable(controller: controller, height: 200), width: 350));
    await tester.pump();

    final indexWidth = controller.columnWidthOf(controller.columns.first)!;
    final firstIndexCell = ordinalRender(tester, 1);
    expect((firstIndexCell.parent! as ElRenderView).size.width, indexWidth);
    expect(
      contentTopLeft(tester, '员工 1').dx - (firstIndexCell.parent! as ElRenderView).localToGlobal(Offset.zero).dx,
      indexWidth + 48,
    );
    expect(contentRender(tester, '员工 1').size.width, 140, reason: '普通列仍读取宽度覆盖');

    controller.data = [
      for (var i = 0; i < 10000; i++) {'id': i, 'name': '员工 ${i + 1}'},
    ];
    await tester.pump();
    final scrolling = controller.scrollTo(9999);
    await tester.pumpAndSettle();
    await scrolling;

    final render = ordinalRender(tester, 10000);
    expect((render.parent! as ElRenderView).size.width, greaterThan(64));
    expect((render.parent! as ElRenderView).size.width, controller.columnWidthOf(controller.columns.first));
    expect(ordinalRender(tester, 10000).debugPaintEntries.single.label, '10000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('序号列按级联生效的文字样式实测字宽，跨位序号不折行', (tester) async {
    // 回归：序号列宽曾按 el_ui 文本初值（字号 15）硬测数字宽，而单元格用的是
    // 级联生效的字号/字体。两者不一致时预留宽度偏窄，末位序号被挤到第二行。
    // 这里让祖先级联声明更大的字号，复刻"测量基准 ≠ 渲染基准"。
    Future<ElTableController> buildTable(WidgetTester tester, double ancestorFontSize, {int rows = 10000}) async {
      final controller = ElTableController(
        rowKey: 'id',
        data: [
          for (var row = 0; row < rows; row++) {'id': row, 'name': '员工 ${row + 1}'},
        ],
        columns: [
          ElTableColumn(type: .index, width: 64, fixed: .left),
          ElTableColumn(title: '姓名', prop: 'name', width: 120),
        ],
      );
      addTearDown(controller.dispose);
      addTearDown(() => tester.pumpWidget(SizedBox.shrink()));
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: ElView(
            style: ElStyle(fontSize: ancestorFontSize),
            child: Align(
              alignment: .topLeft,
              child: SizedBox(width: 420, height: 200, child: ElTable(controller: controller, height: 200)),
            ),
          ),
        ),
      );
      await tester.pump();
      final widthBeforeScroll = controller.columnWidthOf(controller.columns.first);
      final scrolling = controller.scrollTo(9999);
      await tester.pumpAndSettle();
      await scrolling;
      expect(controller.columnWidthOf(controller.columns.first), widthBeforeScroll, reason: '序号列按总行数定宽，不得随虚拟视口滚动改变');
      return controller;
    }

    // 一位数序号：按实际一字符和两侧 padding 预留。
    final oneDigit = await buildTable(tester, 14, rows: 9);
    expect(oneDigit.columnWidthOf(oneDigit.columns.first), 14 + 24, reason: '一位数序号使用一字符宽度');

    // 序号单元格的文字样式由级联决定，列宽必须跟着它走，而不是跟着固定初值。
    final base = await buildTable(tester, 14);
    final baseWidth = base.columnWidthOf(base.columns.first)!;
    expect(baseWidth, 14 * 5 + 24, reason: '五位数序号按生效字号预留');
    final tall = await buildTable(tester, 20);
    final tallWidth = tall.columnWidthOf(tall.columns.first)!;
    expect(tallWidth, greaterThan(baseWidth), reason: '字号变大，序号列宽必须跟着变');
    expect(tallWidth, greaterThanOrEqualTo(20 * 5 + 24), reason: '预留宽度要容得下 5 位序号 + 内边距');

    expect(ordinalRender(tester, 10000).debugPaintEntries.single.label, '10000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('整块表头按列初始方向排序并只展示当前方向', (tester) async {
    final semantics = tester.ensureSemantics();
    ElTableSort? changed;
    var clearCount = 0;
    ElTableHeaderCellScope? headerScope;
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ],
      columns: const [
        ElTableColumn(title: '名称', prop: 'name', sort: true, headerAlign: TextAlign.right, initialSortAscending: false),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(
        ElTable(
          controller: controller,
          onSort: (value) => changed = value,
          onClearSort: () => clearCount++,
          headerCellBuilder: (context, header) {
            headerScope = header;
            return header.defaultCell;
          },
        ),
      ),
    );

    expect(contentTopLeft(tester, 'Alice').dy, lessThan(contentTopLeft(tester, 'Bob').dy));
    expect(find.bySemanticsLabel('排序 名称，未排序'), findsOneWidget);
    expect(find.bySemanticsLabel('升序排序 名称'), findsNothing);
    expect(find.bySemanticsLabel('降序排序 名称'), findsNothing);
    await tester.tap(find.bySemanticsLabel('排序 名称，未排序'));
    await tester.pump();

    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: false));
    expect(changed, controller.sortState);
    expect(contentTopLeft(tester, 'Bob').dy, lessThan(contentTopLeft(tester, 'Alice').dy));
    expect(find.bySemanticsLabel('排序 名称，降序'), findsOneWidget);
    final indicator = tester.renderObject<ElRenderView>(
      find.byWidgetPredicate((widget) => widget is ElView && widget.style?.width == 8 && widget.style?.height == 5),
    );
    final headerRect = tester.getRect(find.bySemanticsLabel('排序 名称，降序'));
    expect(indicator.localToGlobal(Offset.zero).dx, lessThanOrEqualTo(headerRect.left + 24));
    expect(contentTopLeft(tester, '名称').dx, greaterThan(headerRect.center.dx));

    await tester.tap(find.bySemanticsLabel('排序 名称，降序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: true));
    expect(find.bySemanticsLabel('排序 名称，升序'), findsOneWidget);
    expect(clearCount, 0);

    headerScope!.clearSort!();
    await tester.pump();
    expect(controller.sortState, isNull);
    expect(clearCount, 1);
    semantics.dispose();
  });

  testWidgets('表头点击三态循环：升序 → 降序 → 清除', (tester) async {
    final semantics = tester.ensureSemantics();
    var sortCount = 0;
    var clearCount = 0;
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name', sort: true)],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(ElTable(controller: controller, onSort: (_) => sortCount++, onClearSort: () => clearCount++)),
    );

    expect(find.bySemanticsLabel('排序 名称，未排序'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('排序 名称，未排序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: true));
    expect(find.bySemanticsLabel('排序 名称，升序'), findsOneWidget);
    expect(contentTopLeft(tester, 'Alice').dy, lessThan(contentTopLeft(tester, 'Bob').dy));

    await tester.tap(find.bySemanticsLabel('排序 名称，升序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: false));
    expect(find.bySemanticsLabel('排序 名称，降序'), findsOneWidget);
    expect(contentTopLeft(tester, 'Bob').dy, lessThan(contentTopLeft(tester, 'Alice').dy));
    expect(clearCount, 0);

    await tester.tap(find.bySemanticsLabel('排序 名称，降序'));
    await tester.pump();
    expect(controller.sortState, isNull);
    expect(controller.sortColumnKey, isNull);
    expect(controller.sortAscending, isNull);
    expect(find.bySemanticsLabel('排序 名称，未排序'), findsOneWidget);
    expect(find.bySemanticsLabel('排序 名称，降序'), findsNothing);
    expect(contentTopLeft(tester, 'Alice').dy, lessThan(contentTopLeft(tester, 'Bob').dy));
    expect(sortCount, 2);
    expect(clearCount, 1);

    await tester.tap(find.bySemanticsLabel('排序 名称，未排序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: true));
    expect(sortCount, 3);
    semantics.dispose();
  });

  testWidgets('sortRequired：重复点击只在升⇄降之间切，清除入口全部不生效', (tester) async {
    final semantics = tester.ensureSemantics();
    var sortCount = 0;
    var clearCount = 0;
    ElTableHeaderCellScope? headerScope;
    final controller = ElTableController(
      rowKey: 'id',
      sortRequired: true,
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name', sort: true)],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(
        ElTable(
          controller: controller,
          onSort: (_) => sortCount++,
          onClearSort: () => clearCount++,
          headerCellBuilder: (context, header) {
            headerScope = header;
            return header.defaultCell;
          },
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('排序 名称，未排序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: true));

    await tester.tap(find.bySemanticsLabel('排序 名称，升序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: false));

    await tester.tap(find.bySemanticsLabel('排序 名称，降序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: true));
    expect(find.bySemanticsLabel('排序 名称，未排序'), findsNothing);
    expect(contentTopLeft(tester, 'Alice').dy, lessThan(contentTopLeft(tester, 'Bob').dy));

    await tester.tap(find.bySemanticsLabel('排序 名称，升序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: false));
    expect(sortCount, 4);
    expect(clearCount, 0);

    expect(headerScope!.sorted, isTrue);
    expect(headerScope!.clearSort, isNull, reason: 'sortRequired 下 scope 不提供清除入口。');

    var notified = 0;
    controller.addListener(() => notified++);
    controller.clearSort();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: false));
    expect(notified, 0, reason: '清除命令在 sortRequired 下必须整个短路。');
    expect(clearCount, 0);
    semantics.dispose();
  });

  testWidgets('sortRequired 动态切换只约束后续点击，不改动当前排序状态', (tester) async {
    final semantics = tester.ensureSemantics();
    var clearCount = 0;
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name', sort: true)],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, onClearSort: () => clearCount++)));

    expect(controller.sortRequired, isFalse);
    await tester.tap(find.bySemanticsLabel('排序 名称，未排序'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('排序 名称，升序'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('排序 名称，降序'));
    await tester.pump();
    expect(controller.sortState, isNull, reason: '默认仍走完整三态，第三下清除。');
    expect(clearCount, 1);

    controller.sortRequired = true;
    await tester.pump();
    expect(controller.sortState, isNull, reason: '切到 true 不自动补排序，也不改动状态。');
    expect(clearCount, 1);

    await tester.tap(find.bySemanticsLabel('排序 名称，未排序'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('排序 名称，升序'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('排序 名称，降序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: true));
    expect(clearCount, 1, reason: '切到 true 后点击不再触发清除。');

    controller.sortRequired = false;
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: true), reason: '切回 false 不动当前排序。');
    await tester.tap(find.bySemanticsLabel('排序 名称，升序'));
    await tester.pump();
    expect(controller.sortState, const ElTableSort(columnKey: 'name', ascending: false));
    await tester.tap(find.bySemanticsLabel('排序 名称，降序'));
    await tester.pump();
    expect(controller.sortState, isNull);
    expect(clearCount, 2, reason: '切回 false 后第三态恢复为清除。');
    semantics.dispose();
  });

  testWidgets('横向拖拽表头提交顶层列顺序', (tester) async {
    List<Object>? changedOrder;
    final controller = ElTableController(
      columns: const [
        ElTableColumn(key: 'name', title: '名称', prop: 'name', width: 100),
        ElTableColumn(key: 'age', title: '年龄', prop: 'age', width: 100),
        ElTableColumn(key: 'status', title: '状态', prop: 'status', width: 100),
      ],
      data: const [
        {'name': 'Alice', 'age': 18, 'status': '启用'},
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      shell(
        ElTable(controller: controller, columnReorderable: true, onColumnOrderChanged: (value) => changedOrder = value),
        width: 300,
      ),
    );

    final name = contentRender(tester, '名称');
    await tester.dragFrom(name.localToGlobal(name.size.center(Offset.zero)), const Offset(220, 0));
    await tester.pumpAndSettle();

    expect(controller.columnOrderKeys, const ['age', 'status', 'name']);
    expect(changedOrder, const ['age', 'status', 'name']);
    expect(contentTopLeft(tester, '年龄').dx, lessThan(contentTopLeft(tester, '状态').dx));
    expect(contentTopLeft(tester, '状态').dx, lessThan(contentTopLeft(tester, '名称').dx));
  });

  testWidgets('固定列换序只在同一固定带内生效', (tester) async {
    final controller = ElTableController(
      columns: const [
        ElTableColumn(key: 'left-a', title: '左 A', prop: 'leftA', width: 100, fixed: .left),
        ElTableColumn(key: 'left-b', title: '左 B', prop: 'leftB', width: 100, fixed: .left),
        ElTableColumn(key: 'middle', title: '中间', prop: 'middle', width: 100),
      ],
      data: const [
        {'leftA': 'LA', 'leftB': 'LB', 'middle': 'M'},
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      shell(ElTable(controller: controller, columnReorderable: true, height: 100), width: 300, height: 100),
    );

    final left = contentRender(tester, '左 A');
    await tester.dragFrom(left.localToGlobal(left.size.center(Offset.zero)), const Offset(280, 0));
    await tester.pumpAndSettle();

    expect(controller.columnOrderKeys, const ['left-b', 'left-a', 'middle']);
    expect(contentTopLeft(tester, '左 B').dx, lessThan(contentTopLeft(tester, '左 A').dx));
    expect(contentTopLeft(tester, '左 A').dx, lessThan(contentTopLeft(tester, '中间').dx));
  });

  testWidgets('多级表头换序按顶层分组整体移动', (tester) async {
    final controller = ElTableController(
      columns: const [
        ElTableColumn(
          key: 'identity',
          title: '身份',
          children: [
            ElTableColumn(key: 'name', title: '姓名', prop: 'name', width: 80),
            ElTableColumn(key: 'role', title: '角色', prop: 'role', width: 80),
          ],
        ),
        ElTableColumn(
          key: 'metric',
          title: '指标',
          children: [
            ElTableColumn(key: 'score', title: '分数', prop: 'score', width: 80),
            ElTableColumn(key: 'level', title: '等级', prop: 'level', width: 80),
          ],
        ),
      ],
      data: const [
        {'name': 'Alice', 'role': 'Admin', 'score': 90, 'level': 'A'},
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(shell(ElTable(controller: controller, columnReorderable: true), width: 320));

    final name = contentRender(tester, '姓名');
    await tester.dragFrom(name.localToGlobal(name.size.center(Offset.zero)), const Offset(220, 0));
    await tester.pumpAndSettle();

    expect(controller.columnOrderKeys, const ['metric', 'identity']);
    expect(contentTopLeft(tester, '指标').dx, lessThan(contentTopLeft(tester, '身份').dx));
    expect(contentTopLeft(tester, '分数').dx, lessThan(contentTopLeft(tester, '姓名').dx));
    expect(contentTopLeft(tester, 90).dx, lessThan(contentTopLeft(tester, 'Alice').dx));
  });

  testWidgets('表头换序过程中整列跟手且相邻列动画让位', (tester) async {
    final controller = ElTableController(
      columns: const [
        ElTableColumn(key: 'name', title: '名称', prop: 'name', width: 100),
        ElTableColumn(key: 'age', title: '年龄', prop: 'age', width: 100),
        ElTableColumn(key: 'status', title: '状态', prop: 'status', width: 100),
      ],
      data: const [
        {'name': 'Alice', 'age': 18, 'status': '启用'},
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      shell(
        ElTable(controller: controller, columnReorderable: true, style: const _DragHeaderSurfaceTableStyle()),
        width: 300,
      ),
    );
    final reorderableHeaders = tester.widgetList<ElView>(
      find.descendant(
        of: find.byType(ElTable),
        matching: find.byWidgetPredicate((widget) => widget is ElView && widget.event?.onHorizontalDragStart != null),
      ),
    );
    expect(reorderableHeaders, isNotEmpty);
    expect(reorderableHeaders.every((view) => view.style?.cursor == null), isTrue, reason: '表头换序不能覆盖鼠标光标。');

    final nameStart = contentTopLeft(tester, '名称').dx;
    final aliceStart = contentTopLeft(tester, 'Alice').dx;
    final ageStart = contentTopLeft(tester, '年龄').dx;
    final ageValueStart = contentTopLeft(tester, 18).dx;
    final name = contentRender(tester, '名称');
    final gesture = await tester.startGesture(name.localToGlobal(name.size.center(Offset.zero)));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(170, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    final draggedHeader = tester
        .widgetList<ElView>(
          find.descendant(
            of: find.byType(ElTable),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ElView &&
                  widget.event?.onHorizontalDragStart != null &&
                  widget.style?.bgColor == const Color(0xffdcecff),
            ),
          ),
        )
        .single;
    expect(draggedHeader.style?.opacity, isNull);
    expect(draggedHeader.style?.boxShadow, isNull);
    expect(controller.columnOrderKeys, const ['name', 'age', 'status'], reason: '拖动期间只做视觉投影，不提前污染配置。');
    expect(contentTopLeft(tester, '名称').dx, greaterThan(nameStart + 150));
    expect(contentTopLeft(tester, 'Alice').dx, greaterThan(aliceStart + 150), reason: '数据区必须和表头使用同一份整列位移。');
    expect(contentTopLeft(tester, '年龄').dx, lessThan(ageStart - 50));
    expect(contentTopLeft(tester, 18).dx, lessThan(ageValueStart - 50), reason: '目标之间的相邻整列必须实时让位。');

    await gesture.up();
    await tester.pump();
    expect(controller.columnOrderKeys, const ['name', 'age', 'status'], reason: '吸附动画完成前仍不提交顺序。');
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.columnOrderKeys, const ['age', 'status', 'name']);
    await tester.pump();
  });

  testWidgets('列级表头优先于 title 且动态单元格样式按行生效', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice', 'hot': true},
        {'id': 2, 'name': 'Bob', 'hot': false},
      ],
      columns: [
        ElTableColumn(
          title: '名称',
          prop: 'name',
          headerBuilder: (context, header) => '列级表头',
          cellStyleBuilder: (cell) => cell.row['hot'] == true ? const ElStyle(bgColor: Color(0xffffcc66)) : null,
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller)));

    expect(contentRenders(tester, (value) => value == '列级表头'), hasLength(1));
    expect(contentRenders(tester, (value) => value == '名称'), isEmpty, reason: '列级 headerBuilder 接管表头内容。');
    expect(contentRender(tester, 'Alice').committedResolvedStyle.box.bgColor, const Color(0xffffcc66));
    expect(contentRender(tester, 'Bob').committedResolvedStyle.box.bgColor, isNull);
  });

  testWidgets('默认排序保持等值行原序并复用双向排序缓存', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice', 'score': 2},
        {'id': 2, 'name': 'Bob', 'score': 1},
        {'id': 3, 'name': 'Carol', 'score': 2},
        {'id': 4, 'name': 'David', 'score': 1},
      ],
      columns: const [
        ElTableColumn(title: '评分', prop: 'score', sort: true),
        ElTableColumn(title: '姓名', prop: 'name'),
      ],
    );
    addTearDown(controller.dispose);

    controller.sort('score');
    await tester.pumpWidget(shell(ElTable(controller: controller)));
    expect(contentTopLeft(tester, 'Bob').dy, lessThan(contentTopLeft(tester, 'David').dy));
    expect(contentTopLeft(tester, 'David').dy, lessThan(contentTopLeft(tester, 'Alice').dy));
    expect(contentTopLeft(tester, 'Alice').dy, lessThan(contentTopLeft(tester, 'Carol').dy));

    controller.sort('score', ascending: false);
    await tester.pump();
    expect(contentTopLeft(tester, 'Alice').dy, lessThan(contentTopLeft(tester, 'Carol').dy));
    expect(contentTopLeft(tester, 'Carol').dy, lessThan(contentTopLeft(tester, 'Bob').dy));
    expect(contentTopLeft(tester, 'Bob').dy, lessThan(contentTopLeft(tester, 'David').dy));
  });

  testWidgets('checkbox 表头与行控件执行三态选择', (tester) async {
    final semantics = tester.ensureSemantics();
    ElTableSelectionChange? changed;
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
        {'id': 3, 'name': 'Carol'},
      ],
      columns: [
        ElTableColumn(type: .checkbox, selectable: (row) => row['id'] != 3),
        const ElTableColumn(title: '名称', prop: 'name'),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, onSelectionChanged: (change) => changed = change)));
    expect(
      find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'Alice'),
      findsNothing,
      reason: 'checkbox 只保留控件 Element，同行纯值列仍应由 render 托管。',
    );

    await tester.tap(find.bySemanticsLabel('选择行 1'));
    await tester.pump();
    expect(controller.selectedRowKeys, {1});
    expect(controller.selectionState(where: controller.columns.first.selectable), ElTableSelectionState.partial);
    expect(changed?.row?.row['name'], 'Alice');
    expect(changed?.selected, isTrue);

    await tester.tap(find.bySemanticsLabel('全选'));
    await tester.pump();
    expect(controller.selectedRowKeys, {1, 2});
    expect(controller.selectionState(where: controller.columns.first.selectable), ElTableSelectionState.all);

    await tester.tap(find.bySemanticsLabel('全选'));
    await tester.pump();
    expect(controller.selectedRowKeys, isEmpty);
    semantics.dispose();
  });

  testWidgets('不设列类型的列按普通数据列渲染', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);
    final column = controller.columns.single;

    expect(column.type, isNull);
    expect(controller.columnWidthOf(column), isNull, reason: '普通数据列没有内置默认列宽。');
    expect(controller.columnAlignOf(column), isNull);
    expect(controller.columnResizableOf(column), isNull);

    await tester.pumpWidget(shell(ElTable(controller: controller)));

    expect(contentRenders(tester, (value) => value == '名称'), hasLength(1));
    expect(contentRenders(tester, (value) => value == 'Alice'), hasLength(1));
  });

  testWidgets('index 列显示展示序号从 1 起且列宽随行数位数自适应', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: [
        for (var index = 0; index < 9; index++) {'id': index, 'name': 'row-$index'},
      ],
      columns: const [
        ElTableColumn(type: .index),
        ElTableColumn(title: '名称', prop: 'name'),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller), width: 420, height: 600));

    for (final label in const [1, 2, 9]) {
      expect(ordinalRenders(tester, label), hasLength(1), reason: '展示序号从 1 起。');
    }
    expect(
      ordinalRender(tester, 1).localToGlobal(Offset.zero).dy,
      lessThan(ordinalRender(tester, 2).localToGlobal(Offset.zero).dy),
    );
    expect(
      ordinalRender(tester, 2).localToGlobal(Offset.zero).dy,
      lessThan(ordinalRender(tester, 3).localToGlobal(Offset.zero).dy),
    );

    final oneDigitWidth = controller.columnWidthOf(controller.columns.first)!;
    expect(
      (ordinalRender(tester, 1).parent! as ElRenderView).size.width,
      closeTo(oneDigitWidth, .001),
      reason: '计划里的行号列宽必须落到列几何。',
    );

    controller.data = [
      for (var index = 0; index < 10; index++) {'id': index, 'name': 'row-$index'},
    ];
    await tester.pump();

    expect(ordinalRenders(tester, 10), hasLength(1));
    expect(
      (ordinalRender(tester, 1).parent! as ElRenderView).size.width,
      closeTo(controller.columnWidthOf(controller.columns.first)!, .001),
    );
    expect(
      (ordinalRender(tester, 1).parent! as ElRenderView).size.width,
      greaterThan(oneDigitWidth),
      reason: '多一位行号必须更宽。',
    );
  });

  testWidgets('expanded 与行事件共享 controller 状态', (tester) async {
    final semantics = tester.ensureSemantics();
    bool? expanded;
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: const [
        ElTableColumn(type: .expanded),
        ElTableColumn(title: '名称', prop: 'name'),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(ElTable(controller: controller, onExpansionChanged: (row, value) => expanded = value)),
    );

    await tester.tap(find.bySemanticsLabel('展开行 1'));
    await tester.pump();
    expect(controller.expandedRowKeys, {1});
    expect(expanded, isTrue);
    expect(find.bySemanticsLabel('收起行 1'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('expand 列 slotBuilder 渲染行详情且保留内置箭头', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: [
        ElTableColumn(type: .expanded, slotBuilder: (context, cell) => 'detail-${cell.row['name']}'),
        const ElTableColumn(title: '名称', prop: 'name'),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller)));
    expect(find.bySemanticsLabel('展开行 1'), findsOneWidget);
    expect(contentRenders(tester, (value) => value == 'detail-Alice'), isEmpty);

    await tester.tap(find.bySemanticsLabel('展开行 1'));
    await tester.pump();
    expect(find.bySemanticsLabel('收起行 1'), findsOneWidget);
    expect(contentRenders(tester, (value) => value == 'detail-Alice'), hasLength(1));
    expect(contentTopLeft(tester, 'detail-Alice').dy, greaterThan(contentTopLeft(tester, 'Alice').dy));

    await tester.tap(find.bySemanticsLabel('收起行 1'));
    await tester.pump();
    expect(contentRenders(tester, (value) => value == 'detail-Alice'), isEmpty);
    semantics.dispose();
  });

  testWidgets('固定列横滚时展开详情冻结在 viewport', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'left': 'fixed-left', 'middle': 'moving-middle', 'right': 'fixed-right'},
      ],
      columns: [
        ElTableColumn(
          type: .expanded,
          fixed: .left,
          slotBuilder: (context, cell) => const ElView(style: ElStyle(height: 48), child: 'fixed-detail'),
        ),
        const ElTableColumn(title: '左', prop: 'left', width: 80, fixed: .left),
        const ElTableColumn(title: '中', prop: 'middle', width: 320),
        const ElTableColumn(title: '右', prop: 'right', width: 80, fixed: .right),
      ],
    );
    addTearDown(controller.dispose);
    controller.expand(controller.data.single);

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 180), width: 240, height: 180));
    await tester.pump();

    final detailBefore = contentTopLeft(tester, 'fixed-detail').dx;
    final middleBefore = contentTopLeft(tester, 'moving-middle').dx;
    await tester.dragFrom(const Offset(150, 120), const Offset(-140, 0));
    await tester.pumpAndSettle();

    expect(contentTopLeft(tester, 'fixed-detail').dx, closeTo(detailBefore, 1));
    expect(contentTopLeft(tester, 'moving-middle').dx, lessThan(middleBefore - 60));
  });

  testWidgets('行虚拟化支持可变高展开项与 scrollTo', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: [
        for (var index = 0; index < 100; index++) {'id': index, 'name': 'virtual-row-$index'},
      ],
      columns: [
        ElTableColumn(
          type: .expanded,
          slotBuilder: (context, cell) => const ElView(style: ElStyle(height: 100), child: 'virtual-detail'),
        ),
        const ElTableColumn(title: '名称', prop: 'name', width: 160),
      ],
    );
    addTearDown(controller.dispose);
    controller.expand(controller.data.first);

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 160), width: 240, height: 160));
    expect(contentRenders(tester, (value) => value == 'virtual-detail'), hasLength(1));

    final scrolling = controller.scrollTo(20);
    await tester.pumpAndSettle();
    expect(await scrolling, isTrue);
    expect(contentRenders(tester, (value) => value == 'virtual-row-20'), hasLength(1));
  });

  testWidgets('非虚拟 scrollTo 计入前置展开详情高度', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: [
        for (var index = 0; index < 20; index++) {'id': index, 'name': 'plain-row-$index'},
      ],
      columns: [
        ElTableColumn(
          type: .expanded,
          slotBuilder: (context, cell) => const ElView(style: ElStyle(height: 100), child: 'plain-detail'),
        ),
        const ElTableColumn(title: '名称', prop: 'name', width: 160),
      ],
    );
    addTearDown(controller.dispose);
    controller.expand(controller.data.first);

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 160), width: 240, height: 160));
    final scrolling = controller.scrollTo(5);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(await scrolling, isTrue);
    expect(contentTopLeft(tester, 'plain-row-5').dy, lessThan(90));
  });

  testWidgets('普通行只有声明行事件后才启用用户当前行命中', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller)));
    await tapContent(tester, 'Alice');
    await tester.pump();
    expect(controller.currentRow, isNull);

    await tester.pumpWidget(shell(ElTable(controller: controller, onCurrentChanged: (_) {})));
    await tapContent(tester, 'Alice');
    await tester.pump();
    expect(controller.currentRowKey, 1);
  });

  testWidgets('焦点键盘按展示顺序移动当前行并滚动虚拟 viewport', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    final controller = ElTableController(
      rowKey: 'id',
      pinnedRowKeys: const [0],
      data: [
        {'id': 0, 'name': 'pinned', 'score': 0},
        for (var index = 1; index < 10; index++) {'id': index, 'name': 'row-$index', 'score': index},
      ],
      columns: const [
        ElTableColumn(title: '名称', prop: 'name'),
        ElTableColumn(prop: 'score', sort: true),
      ],
    );
    addTearDown(controller.dispose);
    controller.sort('score', ascending: false);
    final changes = <Object>[];

    await tester.pumpWidget(
      shell(
        ElTable(
          controller: controller,
          focusNode: focusNode,
          onCurrentChanged: (row) {
            if (row != null) changes.add(row['id']!);
          },
          height: 160,
        ),
        height: 160,
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.currentRowKey, 0, reason: '无当前行时 ArrowDown 应从固定行开始。');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.currentRowKey, 9, reason: '固定行之后应进入已排序 body。');

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(controller.currentRowKey, 6);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(controller.currentRowKey, 9);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(controller.currentRowKey, 1);
    expect(contentRenders(tester, (value) => value == 'row-1'), hasLength(1), reason: '键盘移动必须同步揭示离屏当前行。');
    final changeCount = changes.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.currentRowKey, 1);
    expect(changes, hasLength(changeCount), reason: '到达边界后重复方向键不应重复触发当前行事件。');

    controller.currentRowKey = null;
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(controller.currentRowKey, 1, reason: '无当前行时 ArrowUp 应从末行开始。');
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(controller.currentRowKey, 0);
  });

  testWidgets('横向滚动时左右固定列保持在 viewport 两侧', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'left': 'fixed-left', 'middle': 'moving-middle', 'right': 'fixed-right'},
      ],
      columns: const [
        ElTableColumn(title: '左', prop: 'left', width: 80, fixed: .left),
        ElTableColumn(title: '中', prop: 'middle', width: 320),
        ElTableColumn(title: '右', prop: 'right', width: 80, fixed: .right),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 120), width: 240, height: 120));
    await tester.pump();

    final leftBefore = contentTopLeft(tester, 'fixed-left').dx;
    final middleBefore = contentTopLeft(tester, 'moving-middle').dx;
    final rightBefore = contentTopLeft(tester, 'fixed-right').dx;
    await tester.dragFrom(const Offset(150, 80), const Offset(-140, 0));
    await tester.pumpAndSettle();

    expect(contentTopLeft(tester, 'fixed-left').dx, closeTo(leftBefore, 1));
    expect(contentTopLeft(tester, 'moving-middle').dx, lessThan(middleBefore - 60));
    expect(contentTopLeft(tester, 'fixed-right').dx, closeTo(rightBefore, 1));
  });

  testWidgets('固定列分界线覆盖相邻列线且只占一个像素列', (tester) async {
    const boundaryKey = ValueKey('fixed-divider-boundary');
    final controller = ElTableController(
      data: const [
        {'left': 'L', 'middle': 'M', 'right': 'R'},
      ],
      columns: const [
        ElTableColumn(title: '左', prop: 'left', width: 80, fixed: .left),
        ElTableColumn(title: '中', prop: 'middle', width: 200),
        ElTableColumn(title: '右', prop: 'right', width: 80, fixed: .right),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(
        RepaintBoundary(
          key: boundaryKey,
          child: ElTable(controller: controller, style: const _FixedDividerTableStyle(), height: 120),
        ),
        width: 240,
        height: 120,
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final capture = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return (image: image, bytes: bytes);
    });
    final image = capture!.image;
    final bytes = capture.bytes;

    Color pixel(int x, int y) {
      final offset = (y * image.width + x) * 4;
      return Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }

    expect(pixel(79, 60), const Color(0xffffffff));
    expect(pixel(80, 60), const Color(0xff0000ff));
    expect(pixel(81, 60), const Color(0xffffffff));
    expect(pixel(159, 60), const Color(0xffffffff));
    expect(pixel(160, 60), const Color(0xff0000ff));
    expect(pixel(161, 60), const Color(0xffffffff));
    image.dispose();
  });

  testWidgets('auto 在最小列宽总和溢出后正文可横向拖动', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'first': 'auto-first', 'second': 'auto-second'},
      ],
      columns: const [
        ElTableColumn(title: '第一列', prop: 'first', minWidth: 180),
        ElTableColumn(title: '第二列', prop: 'second', minWidth: 180),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 100), width: 240, height: 100));
    await tester.pump();
    final before = contentTopLeft(tester, 'auto-second').dx;
    // 此测试只验证 auto 溢出后的正文横向滚动，不把底部 scrollbar 的命中契约混进来。
    await tester.dragFrom(const Offset(150, 50), const Offset(-100, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(contentTopLeft(tester, 'auto-second').dx, lessThan(before - 40));
  });

  testWidgets('行虚拟化只挂载 viewport 邻近数据', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: [
        for (var index = 0; index < 1000; index++) {'id': index, 'name': 'row-$index'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name', width: 160)],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 160), width: 240, height: 160));

    final mounted = contentRenders(tester, (value) => '$value'.startsWith('row-')).length;
    expect(mounted, greaterThan(0));
    expect(mounted, lessThan(40));
  });

  testWidgets('同 key 热更新 viewport 高度立即生效，行虚拟化恒开只挂窗口内的行', (tester) async {
    const viewKey = ValueKey<String>('hot-viewport-table');
    final controller = ElTableController(
      rowKey: 'id',
      data: [
        for (var index = 0; index < 50; index++) {'id': index, 'name': 'hot-row-$index'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name', width: 160)],
    );
    addTearDown(controller.dispose);

    Widget build({required double height}) => Directionality(
      textDirection: .ltr,
      child: UnconstrainedBox(
        alignment: .topLeft,
        child: SizedBox(
          width: 200,
          child: ElTable(key: viewKey, controller: controller, height: height),
        ),
      ),
    );

    await tester.pumpWidget(build(height: 120));
    final render = tester.renderObject<RenderBox>(find.byKey(viewKey));
    expect(render.size.height, 120);
    expect(contentRenders(tester, (value) => value == 'hot-row-3'), isEmpty);
    expect(contentRenders(tester, (value) => value == 'hot-row-20'), isEmpty);

    // 行虚拟化恒开：窗口加高只把窗口内的行带进来，第 20 行仍在窗口之外。
    await tester.pumpWidget(build(height: 220));
    expect(tester.renderObject<RenderBox>(find.byKey(viewKey)), same(render));
    expect(render.size.height, 220);
    expect(contentRenders(tester, (value) => value == 'hot-row-3'), hasLength(1));
    expect(contentRenders(tester, (value) => value == 'hot-row-20'), isEmpty);
  });

  testWidgets('纯值单元格由行 render 托管，扩展单元格保留 element 路径', (tester) async {
    final semantics = tester.ensureSemantics();
    ElTableCell? tapped;
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: [
        const ElTableColumn(type: .index),
        ElTableColumn(
          title: '名称',
          prop: 'name',
          cellStyleBuilder: (cell) => const ElStyle(bgColor: Color(0xffffcc66)),
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller)));
    expect(contentRenders(tester, (value) => value == 'Alice'), hasLength(1));
    expect(ordinalRenders(tester, 1), hasLength(1));
    expect(contentRender(tester, 'Alice').committedResolvedStyle.box.bgColor, const Color(0xffffcc66));
    expect(hasSemanticsLabel(tester, 'Alice'), isTrue);
    expect(
      find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'Alice'),
      findsNothing,
      reason: '纯值不应为每个单元格创建 Widget/Element。',
    );

    await tester.pumpWidget(shell(ElTable(controller: controller, onCellTap: (cell) => tapped = cell)));
    expect(
      find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'Alice'),
      findsOneWidget,
      reason: '声明单元格事件后必须保留完整事件节点。',
    );
    await tapContent(tester, 'Alice');
    await tester.pump();
    expect(tapped?.value, 'Alice');
    semantics.dispose();
  });

  testWidgets('列虚拟化只挂载固定带与横向窗口列', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: [
        {'id': 1, for (var index = 0; index < 100; index++) 'c$index': 'value-$index'},
      ],
      columns: [
        for (var index = 0; index < 100; index++)
          ElTableColumn(
            title: 'C$index',
            prop: 'c$index',
            width: 80,
            fixed: index == 0 ? .left : null,
            slotBuilder: index == 1 ? (context, cell) => 'slot-${cell.value}' : null,
          ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 100), width: 320, height: 100));

    final mounted = contentRenders(tester, (value) => '$value'.startsWith('value-')).length;
    expect(mounted, greaterThan(0));
    expect(mounted, lessThan(30));
    expect(
      find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'value-0'),
      findsNothing,
      reason: '稀疏窗口的纯值单元格应直接由行 render 托管。',
    );
    expect(
      find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'slot-value-1'),
      findsOneWidget,
      reason: '同一稀疏行中的 slot 列必须保留完整 Element 扩展路径。',
    );

    await tester.dragFrom(const Offset(260, 70), const Offset(-1800, 0));
    await tester.pumpAndSettle();
    expect(
      contentRenders(tester, (value) {
        final match = RegExp(r'^value-(\d+)$').firstMatch('$value');
        return match != null && int.parse(match.group(1)!) > 10;
      }),
      isNotEmpty,
      reason: '跨横向窗口后必须挂载并绘制新的纯值列。',
    );
  });

  testWidgets('auto 宽表无固定列首帧直接进入列虚拟化', (tester) async {
    final controller = ElTableController(
      data: [
        {'id': 1, for (var index = 0; index < 100; index++) 'c$index': 'auto-value-$index'},
      ],
      columns: [for (var index = 0; index < 100; index++) ElTableColumn(title: 'C$index', prop: 'c$index', width: 80)],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 100), width: 320, height: 100));
    final mounted = contentRenders(tester, (value) => '$value'.startsWith('auto-value-')).length;
    expect(mounted, inInclusiveRange(1, 29), reason: '无固定列宽表首帧不得先挂载全部 100 列。');
  });

  testWidgets('运行时替换 data 和 columns 立即刷新内容', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(shell(ElTable(controller: controller)));
    expect(contentRenders(tester, (value) => value == 'Alice'), hasLength(1));

    controller.update(
      data: const [
        {'id': 2, 'status': 'active'},
      ],
      columns: [ElTableColumn(title: '状态', prop: 'status', slotBuilder: (context, cell) => 'status-${cell.value}')],
    );
    await tester.pump();

    expect(contentRenders(tester, (value) => value == 'Alice'), isEmpty);
    expect(contentRenders(tester, (value) => value == 'status-active'), hasLength(1));
  });

  testWidgets('选择状态变化复用已排序的展示行缓存', (tester) async {
    var comparisons = 0;
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'score': 3},
        {'id': 2, 'score': 1},
        {'id': 3, 'score': 2},
      ],
      columns: [
        ElTableColumn(
          title: '分数',
          prop: 'score',
          sort: true,
          sorter: (a, b) {
            comparisons++;
            return (a['score'] as int).compareTo(b['score'] as int);
          },
        ),
      ],
    );
    addTearDown(controller.dispose);
    controller.sort('score');
    await tester.pumpWidget(shell(ElTable(controller: controller)));
    final baseline = comparisons;
    expect(baseline, greaterThan(0));

    controller.select(controller.data.first);
    await tester.pump();
    expect(comparisons, baseline);

    controller.sort('score', ascending: false);
    await tester.pump();
    expect(comparisons, baseline, reason: '首次排序会同时缓存稳定的升序和降序。');
  });

  testWidgets('列宽拖拽只在结束时提交稳定列 key', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice', 'dept': 'R&D'},
      ],
      columns: const [
        ElTableColumn(key: 'name', title: '名称', prop: 'name', width: 100, resizable: true),
        ElTableColumn(key: 'dept', title: '部门', prop: 'dept', width: 100),
      ],
    );
    addTearDown(controller.dispose);
    Map<Object, double>? resizedColumns;
    await tester.pumpWidget(
      shell(
        ElTable(controller: controller, height: 100, onColumnWidthsChanged: (value) => resizedColumns = value),
        width: 240,
        height: 100,
      ),
    );

    await tester.drag(find.bySemanticsLabel('调整列宽 名称'), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(controller.columnWidths['name'], closeTo(140, 1));
    expect(controller.columnWidths.containsKey('dept'), isFalse);
    expect(resizedColumns, controller.columnWidths);
    semantics.dispose();
  });

  testWidgets('皮肤可为普通列统一开启调宽且列级 false 仍优先', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = ElTableController(
      data: const [
        {'id': 1, 'name': 'Alice', 'dept': 'R&D'},
      ],
      columns: const [
        ElTableColumn(title: '名称', prop: 'name', width: 100),
        ElTableColumn(title: '部门', prop: 'dept', width: 100, resizable: false),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, style: const _SkinHookTableStyle()), width: 220));

    expect(find.bySemanticsLabel('调整列宽 名称'), findsOneWidget);
    expect(find.bySemanticsLabel('调整列宽 部门'), findsNothing);
    semantics.dispose();
  });

  testWidgets('皮肤斑马纹按排序后的展示序号叠加', (tester) async {
    final controller = ElTableController(
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, style: const _SkinHookTableStyle())));

    bool hasBackground(Object value, Color color) {
      RenderObject? node = contentRender(tester, value);
      while (node != null) {
        if (node is ElRenderView && node.committedResolvedStyle.box.bgColor == color) return true;
        node = node.parent;
      }
      return false;
    }

    expect(hasBackground('Alice', const Color(0xff123456)), isFalse);
    expect(hasBackground('Bob', const Color(0xff123456)), isTrue);
  });

  testWidgets('未登记组件主题时裸用 ElTable 按默认皮肤工作', (tester) async {
    final controller = ElTableController(
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(bareHost(ElTable(controller: controller)));

    expect(contentRenders(tester, (value) => value == '名称'), hasLength(1));
    expect(contentRenders(tester, (value) => value == 'Alice'), hasLength(1));
    expect(
      tester.renderObject<RenderBox>(find.byType(ElTable)).size,
      const Size(80, 80),
      reason: '默认皮肤：列宽取 minColumnWidth 80，表头与数据行各 40。',
    );
    expect(tester.takeException(), isNull, reason: '没有 ElComponentProvider 时不得 assert。');
  });

  testWidgets('ElComponentBuilders.tableStyleBuilder 登记的皮肤在裸用 ElTable 时生效', (tester) async {
    final controller = ElTableController(
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ElComponentProvider(
        builders: const ElComponentBuilders(tableStyleBuilder: _themeTableStyleOf),
        child: bareHost(ElTable(controller: controller)),
      ),
    );

    expect(contentRenders(tester, (value) => value == 'Alice'), hasLength(1));
    expect(
      tester.renderObject<RenderBox>(find.byType(ElTable)).size,
      const Size(60, 48),
      reason: '皮肤里声明的 rowHeight 24 与 minColumnWidth 60 必须真的作用到几何上。',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('显式 style 优先于组件主题登记的皮肤', (tester) async {
    final controller = ElTableController(
      data: const [
        {'id': 1, 'name': 'Alice'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ElComponentProvider(
        builders: const ElComponentBuilders(tableStyleBuilder: _themeTableStyleOf),
        child: bareHost(ElTable(controller: controller, style: const _ExplicitTableStyle())),
      ),
    );

    expect(
      tester.renderObject<RenderBox>(find.byType(ElTable)).size,
      const Size(100, 64),
      reason: '显式 style 的 rowHeight 32 / minColumnWidth 100 压过主题的 24 / 60。',
    );
  });

  testWidgets('空态内容只有 emptyBuilder 一个入口，外观由 empty / emptyHeight 决定', (tester) async {
    final controller = ElTableController(
      emptyBuilder: (context, controller) => 'empty-builder-text',
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller), width: 240));
    expect(contentRenders(tester, (value) => value == 'empty-builder-text'), hasLength(1));
    expect(contentRender(tester, 'empty-builder-text').size.height, 80, reason: '默认空态高度是两倍行高。');

    await tester.pumpWidget(shell(ElTable(controller: controller, style: const _EmptyHeightTableStyle()), width: 240));
    expect(contentRenders(tester, (value) => value == 'empty-builder-text'), hasLength(1));
    expect(contentRender(tester, 'empty-builder-text').size.height, 120, reason: 'ElTableStyle.emptyHeight 决定空态高度。');
  });

  testWidgets('隐藏表头与空状态都由 controller 的 emptyBuilder 动态更新', (tester) async {
    Object? emptyText(BuildContext context, ElTableController controller) => '暂无记录';
    final controller = ElTableController(
      showHeader: false,
      emptyBuilder: emptyText,
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller)));
    expect(contentRenders(tester, (value) => value == '名称'), isEmpty);
    expect(contentRenders(tester, (value) => value == '暂无记录'), hasLength(1));

    final empty = contentRender(tester, '暂无记录');
    final glyphs =
        (empty.selectionParticipant?.selectionPaintRectsForRange(const ui.TextRange(start: 0, end: 4)) ??
        const <Rect>[]);
    final glyphBounds = glyphs.reduce((a, b) => a.expandToInclude(b));
    final table = tester.renderObject<RenderBox>(find.byType(ElTable));
    expect(
      empty.localToGlobal(glyphBounds.center).dx,
      closeTo(table.localToGlobal(table.size.center(Offset.zero)).dx, 1),
    );

    controller.data = const [
      {'id': 1, 'name': 'Alice'},
    ];
    await tester.pump();
    expect(contentRenders(tester, (value) => value == '暂无记录'), isEmpty, reason: '有数据时空态必须让位给数据行。');
    expect(contentRenders(tester, (value) => value == 'Alice'), hasLength(1));

    controller
      ..data = const []
      ..showHeader = true
      ..emptyBuilder = null;
    await tester.pump();
    expect(contentRenders(tester, (value) => value == '名称'), hasLength(1));
    expect(contentRenders(tester, (value) => value == '暂无记录'), isEmpty, reason: '清空 emptyBuilder 后空态只剩外观，不再有内容。');
    expect(tester.takeException(), isNull);
  });

  testWidgets('固定行不参与本地排序且合计行固定在 body 之后', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      pinnedRowKeys: const [1],
      data: const [
        {'id': 1, 'name': '置顶', 'score': 9},
        {'id': 2, 'name': '第二', 'score': 3},
        {'id': 3, 'name': '第一', 'score': 1},
        {'id': 4, 'name': '第四', 'score': 4},
        {'id': 5, 'name': '第五', 'score': 5},
        {'id': 6, 'name': '第六', 'score': 6},
      ],
      columns: const [
        ElTableColumn(title: '名称', prop: 'name'),
        ElTableColumn(title: '分数', prop: 'score', sort: true),
      ],
      summaryBuilder: (context, cell) =>
          cell.columnIndex == 0 ? '合计' : cell.data.fold<int>(0, (sum, row) => sum + (row['score'] as int)),
    );
    addTearDown(controller.dispose);
    controller.sort('score');

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 240), height: 240));

    expect(contentTopLeft(tester, '置顶').dy, lessThan(contentTopLeft(tester, '第一').dy));
    expect(contentTopLeft(tester, '第一').dy, lessThan(contentTopLeft(tester, '第二').dy));
    expect(contentTopLeft(tester, '第二').dy, lessThan(contentTopLeft(tester, '合计').dy));
    expect(contentRenders(tester, (value) => value == 28), hasLength(1));

    final pinnedY = contentTopLeft(tester, '置顶').dy;
    final summaryY = contentTopLeft(tester, '合计').dy;
    await tester.dragFrom(const Offset(180, 150), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(contentTopLeft(tester, '置顶').dy, closeTo(pinnedY, 1));
    expect(contentTopLeft(tester, '合计').dy, closeTo(summaryY, 1));
  });

  testWidgets('弹性列按 flex 权重分配剩余宽度', (tester) async {
    final controller = ElTableController(
      data: const [
        {'id': 1, 'a': 'A-flex', 'b': 'B-flex'},
      ],
      columns: const [
        ElTableColumn(title: 'A', prop: 'a', minWidth: 10, flex: 1),
        ElTableColumn(title: 'B', prop: 'b', minWidth: 10, flex: 2),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller), width: 300));
    expect(contentRender(tester, 'A-flex').size.width, closeTo(100, 1));
    expect(contentRender(tester, 'B-flex').size.width, closeTo(200, 1));
  });

  testWidgets('自动行高按换行内容实测且行高拖拽提交到 controller', (tester) async {
    const longText = '这是一段需要在窄列中自动换行并撑高表格行的内容';
    final autoController = ElTableController(
      data: const [
        {'id': 1, 'name': longText},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name', width: 90)],
    );
    addTearDown(autoController.dispose);
    await tester.pumpWidget(
      shell(ElTable(controller: autoController, style: const _AutoHeightTableStyle()), width: 90),
    );
    expect(contentRender(tester, longText).size.height, greaterThan(30));

    final resizeController = ElTableController(
      rowKey: 'id',
      rowResizable: true,
      data: const [
        {'id': 1, 'name': '可调行高'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name', width: 160)],
    );
    addTearDown(resizeController.dispose);
    Map<Object, double>? resizedRows;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      shell(ElTable(controller: resizeController, onRowHeightsChanged: (value) => resizedRows = value), width: 160),
    );
    await tester.drag(find.bySemanticsLabel('调整行高'), const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(resizeController.rowHeights[1], greaterThan(60));
    expect(resizedRows, resizeController.rowHeights);
    semantics.dispose();
  });

  testWidgets('多级表头按叶子列跨度布局', (tester) async {
    final headerScopes = <Object?, ElTableHeaderCellScope>{};
    final controller = ElTableController(
      data: const [
        {'id': 1, 'name': 'Alice', 'role': 'Admin', 'score': 90},
      ],
      columns: const [
        ElTableColumn(
          title: '身份',
          children: [
            ElTableColumn(title: '姓名', prop: 'name', width: 100),
            ElTableColumn(title: '角色', prop: 'role', width: 100),
          ],
        ),
        ElTableColumn(
          title: '指标',
          children: [ElTableColumn(title: '分数', prop: 'score', width: 100)],
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      shell(
        ElTable(
          controller: controller,
          headerCellBuilder: (context, header) {
            headerScopes[header.header.column.title] = header;
            return header.defaultCell;
          },
        ),
        width: 300,
      ),
    );
    expect(contentRender(tester, '身份').size.width, closeTo(200, 1));
    expect(contentRender(tester, '指标').size.width, closeTo(100, 1));
    expect(contentTopLeft(tester, '身份').dy, lessThan(contentTopLeft(tester, '姓名').dy));
    expect(contentTopLeft(tester, '姓名').dy, lessThan(contentTopLeft(tester, 'Alice').dy));
    expect(headerScopes['身份']?.isGroup, isTrue);
    expect(headerScopes['身份']?.columnSpan, 2);
    expect(headerScopes['姓名']?.isGroup, isFalse);
    expect(headerScopes['姓名']?.columnSpan, 1);
  });

  testWidgets('多级表头跨固定带时按带拆分并跟随同一横向真值', (tester) async {
    final controller = ElTableController(
      data: const [
        {'id': 1, 'left': '固定值', 'middle': '滚动值', 'tail': '尾值'},
      ],
      columns: const [
        ElTableColumn(
          title: '固定组',
          children: [ElTableColumn(title: '固定列', prop: 'left', width: 100, fixed: .left)],
        ),
        ElTableColumn(
          title: '滚动组',
          children: [
            ElTableColumn(title: '中间列', prop: 'middle', width: 360),
            ElTableColumn(title: '尾列', prop: 'tail', width: 160),
          ],
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(shell(ElTable(controller: controller, height: 160), width: 260, height: 160));
    // 横向窗口恒按「内容溢出视口」自动启用：首帧布局后才会翻转，等它生效再读基准位置。
    await tester.pump();
    final fixedBefore = contentTopLeft(tester, '固定组').dx;
    final movingBefore = contentTopLeft(tester, '滚动组').dx;
    await tester.dragFrom(const Offset(180, 120), const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(contentTopLeft(tester, '固定组').dx, closeTo(fixedBefore, 1));
    expect(contentTopLeft(tester, '滚动组').dx, lessThan(movingBefore - 60));
  });

  testWidgets('动态单元格样式、溢出策略、直接 sorter 与行事件展示序号生效', (tester) async {
    ElTableRowContext? tapped;
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alpha-very-long-value'},
        {'id': 2, 'name': 'Beta-very-long-value'},
      ],
      columns: [
        ElTableColumn(
          title: '名称',
          prop: 'name',
          width: 80,
          sort: true,
          showOverflow: true,
          cellStyleBuilder: (cell) => const ElStyle(color: Color(0xff123456)),
          headerStyle: const ElStyle(color: Color(0xff654321)),
          sorter: (a, b) => '${b['name']}'.compareTo('${a['name']}'),
        ),
      ],
    );
    addTearDown(controller.dispose);
    controller.sort('name');
    await tester.pumpWidget(shell(ElTable(controller: controller, onRowTap: (row) => tapped = row), width: 80));

    final beta = contentRender(tester, 'Beta-very-long-value');
    expect(beta.committedResolvedStyle.inheritedText.color, const Color(0xff123456));
    expect(beta.committedResolvedStyle.inheritedText.maxLines, 1);
    expect(contentRender(tester, '名称').committedResolvedStyle.inheritedText.color, const Color(0xff654321));
    expect(
      contentTopLeft(tester, 'Beta-very-long-value').dy,
      lessThan(contentTopLeft(tester, 'Alpha-very-long-value').dy),
    );

    await tapContent(tester, 'Beta-very-long-value');
    await tester.pump();
    expect(tapped?.rowKey, 2);
    expect(tapped?.rowIndex, 0);
  });

  testWidgets('双击 / 右键数据行：派发回调前底层已把该行同步为当前行', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);

    ElTableRowContext? doubleTapped;
    Object? currentKeyInsideDoubleTap;
    await tester.pumpWidget(
      shell(
        ElTable(
          controller: controller,
          onRowDoubleTap: (row) {
            doubleTapped = row;
            currentKeyInsideDoubleTap = controller.currentRowKey;
          },
        ),
      ),
    );
    final bob = contentRender(tester, 'Bob');
    final bobCenter = bob.localToGlobal(bob.size.center(Offset.zero));

    expect(controller.currentRow, isNull);
    await tester.tapAt(bobCenter);
    await tester.tapAt(bobCenter);
    await tester.pump();

    expect(doubleTapped?.rowKey, 2, reason: '双击仍要派发到用户回调。');
    expect(currentKeyInsideDoubleTap, 2, reason: '回调里读到的 currentRow 已经是该行（这是旧 WinTable 薄壳的承诺）。');
    expect(controller.currentRowKey, 2);

    ElTableRowContext? secondaryTapped;
    Object? currentKeyInsideSecondaryTap;
    Object? positionInsideSecondaryTap;
    await tester.pumpWidget(
      shell(
        ElTable(
          controller: controller,
          onRowSecondaryTap: (row, globalPosition) {
            secondaryTapped = row;
            currentKeyInsideSecondaryTap = controller.currentRowKey;
            positionInsideSecondaryTap = globalPosition;
          },
        ),
      ),
    );
    controller.currentRowKey = null;
    await tester.pump();

    final alice = contentRender(tester, 'Alice');
    final aliceCenter = alice.localToGlobal(alice.size.center(Offset.zero));
    final secondary = await tester.startGesture(aliceCenter, kind: .mouse, buttons: kSecondaryButton);
    await secondary.up();
    await tester.pump();

    expect(secondaryTapped?.rowKey, 1, reason: '右键仍要派发到用户回调。');
    expect(currentKeyInsideSecondaryTap, 1, reason: '回调里读到的 currentRow 已经是该行。');
    expect(positionInsideSecondaryTap, aliceCenter, reason: '右键回调照旧拿到全局指针位置。');
    expect(controller.currentRowKey, 1);
  });

  testWidgets('当前行同步只走双击 / 右键：单击命中不变，回调内覆盖仍生效', (tester) async {
    final controller = ElTableController(
      rowKey: 'id',
      data: const [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ],
      columns: const [ElTableColumn(title: '名称', prop: 'name')],
    );
    addTearDown(controller.dispose);

    // 只声明双击回调：单击不进入当前行路径（别顺手改到 onRowTap）。
    await tester.pumpWidget(shell(ElTable(controller: controller, onRowDoubleTap: (row) {})));
    final bob = contentRender(tester, 'Bob');
    final bobCenter = bob.localToGlobal(bob.size.center(Offset.zero));
    await tester.tapAt(bobCenter);
    await tester.pump();
    expect(controller.currentRow, isNull, reason: '声明双击回调不该让单击改写当前行。');

    // 调用方仍可在回调里覆盖底层刚设好的当前行。
    Object? syncedKey;
    await tester.pumpWidget(
      shell(
        ElTable(
          controller: controller,
          onRowDoubleTap: (row) {
            syncedKey = controller.currentRowKey;
            controller.currentRowKey = 1;
          },
        ),
      ),
    );
    await tester.tapAt(bobCenter);
    await tester.tapAt(bobCenter);
    await tester.pump();
    expect(syncedKey, 2, reason: '底层先同步。');
    expect(controller.currentRowKey, 1, reason: '回调内部的赋值后写后赢。');
  });
}

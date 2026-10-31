import 'package:flutter_base/desktop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// EP 只保留一份表格皮肤：它登记在 `ElComponentBuilders.tableStyleBuilder` 上，由 el_ui 的
/// `ElTable` 在解析生效皮肤时调用（`table_view.dart` 的 `_resolveStyle`）。渲染 / 布局 /
/// 虚拟化 / 命中 / 排序 / 选择 / 展开全在 el_ui，这里只锁皮肤本身与它的登记通道。
void main() {
  /// 在品牌 App 内解析预设；`vars` 用来换尺寸档或覆写表格 token。
  Future<
    ({ElTableStyle style, Color primary, Color borderColor, Color currentRow})
  >
  resolve(
    WidgetTester tester, {
    Brightness brightness = .light,
    ElLevelType? size,
  }) async {
    late ElTableStyle style;
    late Color primary;
    late Color borderColor;
    late Color currentRow;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElDesktopTheme(
          themeMode: ElThemeMode(brightness: brightness),
          size: size,
          child: ElView(
            style: ElStyle(),
            child: Builder(
              builder: (context) {
                primary = ElThemeData.of(context).primary;
                borderColor = context.elTheme.borderColorLighter;
                currentRow = primary.elLight9(context);
                style = ElementPlusThemeData.tableStyle(context);
                return const ElView();
              },
            ),
          ),
        ),
      ),
    );
    return (
      style: style,
      primary: primary,
      borderColor: borderColor,
      currentRow: currentRow,
    );
  }

  test('EP 的表格通道只有一处：全局预设登记一份返回 ElTableStyle 的工厂', () {
    expect(
      const ElementPlusThemeData().tableStyleBuilder,
      ElementPlusThemeData.tableStyle,
    );
    // 表格的定制通道是样式工厂，不是 Widget builder：上层不接管任何表格实现。
    expect(
      const ElementPlusThemeData().tableStyleBuilder,
      isA<ElTableStyle Function(BuildContext)>(),
    );
    // 同名冲突已消失：下面四个名字在只 import element_plus 时唯一解析到 el_ui 内核。
    expect(ElTable, isNotNull);
    expect(ElTableStyle, isNotNull);
    expect(ElTableController, isNotNull);
    expect(ElTableColumn, isNotNull);
    expect(const ElTableStyle().rowHeight, 40);
  });

  testWidgets('尺寸档驱动行高 / 内边距 / 字号 / 命中尺寸', (tester) async {
    const cases = <(ElLevelType, double, Object, Object, double, double)>[
      // (档位, 行高, 横向内边距, 字号, 控件命中, 调宽命中)
      (.xs, 32, 8, 12.0, 26, 8),
      (.sm, 36, 10, 13.0, 28, 8),
      (.md, 40, 12, 14.0, 30, 8),
      (.lg, 48, 14, 14.0, 40, 10),
      (.xl, 56, 16, 15.0, 44, 10),
    ];
    for (final (size, rowHeight, padding, fontSize, control, resize) in cases) {
      final style = (await resolve(tester, size: size)).style;
      expect(style.rowHeight, rowHeight, reason: '$size 行高');
      expect(
        style.cellPadding.resolve(TextDirection.ltr).left,
        padding,
        reason: '$size 内边距',
      );
      expect(style.table.fontSize, fontSize, reason: '$size 字号');
      expect(style.controlHitSize, control, reason: '$size 控件命中');
      expect(style.resizeHitSize, resize, reason: '$size 调宽命中');
    }
  });

  testWidgets('浅色下逐项还原历史 ElTable 的开关、分隔线与各结构面', (tester) async {
    const divider = Color(0xffebeef5);
    final r = await resolve(tester);
    final style = r.style;
    // 开关：外框与纵横网格线开、斑马纹与当前行高亮关（官方默认）。
    expect(style.border, isTrue);
    expect(style.gridLines, isTrue);
    expect(style.columnResizable, isFalse);
    expect(style.stripe, isFalse);
    expect(style.highlightCurrentRow, isFalse);
    expect(style.minColumnWidth, 80);
    // 分隔线：外框 / 表头下边 / 行下边 / 列左竖线同一个色。
    expect(style.frame.border?.borderTop.borderColor, divider);
    expect(style.header.border?.borderBottom.borderColor, divider);
    expect(style.row.border?.borderBottom.borderColor, divider);
    expect(style.columnDivider?.border?.borderLeft.borderColor, divider);
    expect(style.expanded.border?.borderBottom.borderColor, divider);
    expect(style.summary.border?.borderTop.borderColor, divider);
    expect(style.fixedDividerColor, divider);
    // 结构面：表头底回落行底、悬停底 #f5f7fa、当前行底取主色亮阶。
    expect(style.table.backgroundColor, style.row.backgroundColor);
    expect(style.header.backgroundColor, style.row.backgroundColor);
    expect(style.header.fontWeight, FontWeight.w600);
    expect(style.row.onHover?.backgroundColor, const Color(0xfff5f7fa));
    expect(style.currentRow?.backgroundColor, r.currentRow);
    // 行内控件：选择框描边跟随主题边框色，选中态用主色。
    expect(style.selection.border?.borderTop.borderColor, r.borderColor);
    expect(style.selectionActive.backgroundColor, r.primary);
    expect(style.sortActive.color, r.primary);
    expect(style.expand.color, style.header.color);
    expect(style.fixedColumnShadow, isNotNull);
  });

  testWidgets('暗色下分隔线跟随主题边框色（半透明）', (tester) async {
    final r = await resolve(tester, brightness: .dark);
    final divider = r.borderColor.withValues(alpha: 0.6);
    expect(r.style.row.border?.borderBottom.borderColor, divider);
    expect(r.style.header.border?.borderBottom.borderColor, divider);
    expect(r.style.columnDivider?.border?.borderLeft.borderColor, divider);
    expect(r.style.row.onHover?.backgroundColor, const Color(0xff262727));
  });

  testWidgets('表格实际行样式可微调，copyWith 不改变原预设', (tester) async {
    final r = await resolve(tester);
    final custom = r.style.copyWith(
      row: r.style.row.copyWith(
        onHover: ElStyle(backgroundColor: Color(0xffff0000)),
        border: ElBorder.only(borderBottom: ElBorderSide(borderColor: Color(0xff00ff00))),
      ),
    );
    expect(custom.row.onHover?.backgroundColor, Color(0xffff0000));
    expect(custom.row.border?.borderBottom.borderColor, Color(0xff00ff00));
    final tweaked = r.style.copyWith(
      stripe: true,
      highlightCurrentRow: true,
      border: false,
      columnDivider: null,
      rowHeight: 30,
      empty: const ElStyle(alignment: .center),
    );
    expect(tweaked.stripe, isTrue);
    expect(tweaked.highlightCurrentRow, isTrue);
    expect(tweaked.border, isFalse);
    expect(tweaked.columnDivider, isNull);
    expect(tweaked.rowHeight, 30);
    expect(tweaked.empty.alignment, Alignment.center);
    // 预设实例仍是 const 语义的取值来源：copyWith 不动原实例。
    expect(r.style.stripe, isFalse);
    expect(r.style.border, isTrue);
    expect(r.style.rowHeight, 40);
  });
}

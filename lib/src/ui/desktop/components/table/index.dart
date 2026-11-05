import 'package:flutter/widgets.dart';

import '../../../../flutter/commons/theme/index.dart' show ElThemeContextExt;
import '../../../../flutter/views/table/table.dart' show ElTableStyle;
import '../../../../flutter/views/view/style/style.dart' show ElBorder, ElBorderSide, ElStyle;
import '../../extensions/color.dart';
import '../../extensions/el.dart';

// ───────────────────────────────── 表格 ─────────────────────────────────
//
// 表格的渲染 / 布局 / 虚拟化 / 命中 / 排序 / 选择 / 展开全在 el_ui 的 `ElTable` 内，
// element_plus **不提供任何表格组件、也没有任何表格 Widget builder**：这里只有一份
// 返回 `ElTableStyle` 的皮肤工厂，由 [ElementPlusThemeData] 登记进
// `ElComponents.tableStyle`。用户只写 `ElTable(...)`，品牌差异全部来自这份预设。
//
// 外观开关（外框 / 网格线 / 密度 / 斑马纹 / 当前行）都由 `ElTableStyle` 承担，需要局部改写
// 时基于预设 `copyWith` 微调：
//
// ```dart
// ElTable(
//   controller: controller,
//   style: ElementPlusThemeData.tableStyleBuilder(context).copyWith(border: false, columnDivider: null),
// )
// ```
//
/// Element Plus 表格皮肤：带外框与纵横网格线、密度跟随全局尺寸档。
///
/// 逐项还原历史 `ElTable` 默认外观（尺寸档行高与内边距、`#ebeef5` 分隔线、`#f5f7fa`
/// 悬停底、主色 `elLight9` 当前行底、`w600` 表头），差异只有三处**预设必须拍板**的开关：
/// 外框按官方示例取 `border: true`、斑马纹与当前行高亮按官方默认关闭 —— 需要时用
/// `copyWith(stripe: true)` / `copyWith(highlightCurrentRow: true)` 就地打开。
abstract final class ElTableTheme {
  /// 表格外观工厂：只返回 [ElTableStyle]，不接管任何表格实现。
  static ElTableStyle style(BuildContext context) {
    final compact = context.elComponentCompact();
    final primary = context.elTheme.primary;
    final borderColor = context.elTheme.borderColorLighter;
    final textColor = context.elTheme.textRegular;
    final headerTextColor = context.elTheme.textSecondary;
    final background = context.elTheme.bgColor;
    final rowBackground = background;
    final headerBackground = rowBackground;
    final hoverBackground = context.isDark
        ? const Color(0xff262727)
        : const Color(0xfff5f7fa);
    final currentRowBackground = primary.elLight9(context);
    final expandedBackground = background;
    final fixedColumnShadow = const [
      BoxShadow(color: Color(0x1f000000), blurRadius: 10, spreadRadius: -4),
    ];
    final dark = context.isDark;
    // 分隔线：亮色沿用历史硬编码 `#ebeef5`、暗色为边框色 60% 透明；
    // 声明 `--el-table-border-color` 时两种明暗都直接照用（覆写即接管，不做二次派生）。
    final declaredDivider = null;
    final divider =
        declaredDivider ??
        (dark ? borderColor.withValues(alpha: 0.6) : const Color(0xffebeef5));
    final dividerBorder = ElBorderSide(borderColor: divider);
    final controlHitSize = compact ? 28.0 : 30.0;
    return ElTableStyle(
      // 行高、内边距与字号直接跟随 normal / compact 两态。
      rowHeight: compact ? 36 : 40,
      cellPadding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
      minColumnWidth: 80,
      resizeHitSize: 8,
      columnResizable: false,
      controlHitSize: controlHitSize,
      // 外框与网格线
      border: true,
      frame: ElStyle(border: ElBorder.all(borderColor: divider)),
      gridLines: true,
      columnDivider: ElStyle(border: ElBorder.only(borderLeft: dividerBorder)),
      // 结构面
      table: ElStyle(
        backgroundColor: background,
        color: textColor,
        fontSize: compact ? 13 : 14,
        iconColor: textColor,
      ),
      header: ElStyle(
        backgroundColor: headerBackground,
        color: headerTextColor,
        fontWeight: .w600,
        border: ElBorder.only(borderBottom: dividerBorder),
        iconColor: headerTextColor,
      ),
      row: ElStyle(
        backgroundColor: rowBackground,
        border: ElBorder.only(borderBottom: dividerBorder),
        onHover: ElStyle(backgroundColor: hoverBackground),
      ),
      // 开关：斑马纹与当前行高亮按官方默认关闭（历史 `ElTable` 的默认值也是 false）。
      stripe: false,
      highlightCurrentRow: false,
      expanded: ElStyle(
        padding: const .symmetric(horizontal: 12, vertical: 12),
        backgroundColor: expandedBackground,
        border: ElBorder.only(borderBottom: dividerBorder),
      ),
      summary: ElStyle(
        backgroundColor: headerBackground,
        fontWeight: .w600,
        border: ElBorder.only(borderTop: dividerBorder),
      ),
      // 非数据态
      empty: ElStyle(
        alignment: .center,
        color: textColor.withValues(alpha: 0.6),
        iconColor: textColor.withValues(alpha: 0.6),
      ),
      loading: ElStyle(
        alignment: .center,
        color: textColor.withValues(alpha: 0.6),
        iconColor: textColor.withValues(alpha: 0.6),
      ),
      // 固定列
      fixedDividerColor: divider,
      fixedColumnShadow: fixedColumnShadow,
      // 行内控件
      selection: ElStyle(
        width: 14,
        height: 14,
        alignment: .center,
        backgroundColor: background,
        border: ElBorder.all(borderColor: borderColor),
        borderRadius: .all(Radius.circular(2)),
      ),
      sort: ElStyle(
        width: controlHitSize,
        height: controlHitSize / 2,
        alignment: .center,
        color: borderColor,
        iconColor: borderColor,
      ),
      expand: ElStyle(
        width: controlHitSize,
        height: controlHitSize,
        alignment: .center,
        color: headerTextColor,
        cursor: SystemMouseCursors.click,
        iconColor: headerTextColor,
      ),
      sortActive: ElStyle(color: primary, iconColor: primary),
      selectionActive: ElStyle(
        backgroundColor: primary,
        border: ElBorder.all(borderColor: primary),
      ),
      currentRow: ElStyle(backgroundColor: currentRowBackground),
    );
  }
}

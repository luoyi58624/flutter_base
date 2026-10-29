// ignore_for_file: prefer_initializing_formals
part of 'table.dart';

/// 表格皮肤：整表外观的唯一声明处，上层组件库注入一个实例即可定制全部外观。
///
/// 分区（与表格结构一一对应，除本类以外不再有第二套表格外观类型）：
///
/// - 尺寸与密度 (8)：rowHeight / autoRowHeight / headerHeight / cellPadding /
///   minColumnWidth / resizeHitSize / columnResizable / controlHitSize
/// - 外框与网格线 (7)：border / frame / gridLines / horizontalGridLines /
///   verticalGridLines / rowDivider / columnDivider
/// - 结构面 (13)：table / header / row / stripe / stripeRow /
///   highlightCurrentRow / currentRow / expanded / cell / headerCell /
///   draggingHeaderCell / groupHeader / summary
/// - 非数据态 (4)：empty / emptyHeight / loading / loadError
/// - 固定列 (3)：fixedDividerColor / fixedDividerWidth / fixedColumnShadow
/// - 行内控件 (7)：selection / selectionActive / sort / sortActive / expand / resize / rowResize
///
/// 约定：
///
/// - 外观一律用 [ElStyle] 表达；业务选中外观由表格自行叠加普通样式，
///   不要再造表格自己的样式类型。
/// - 全部字段 `final`：基于预设用 [copyWith] 微调，不要靠继承覆写 getter。
/// - `const ElTableStyle()` 即默认皮肤，各项默认值与历史默认外观逐项一致。
@immutable
class ElTableStyle {
  /// 创建表格皮肤；缺省参数即默认皮肤。
  const ElTableStyle({
    // 尺寸与密度
    this.rowHeight = 40,
    this.autoRowHeight = false,
    this.headerHeight,
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.minColumnWidth = 80,
    this.resizeHitSize = 8,
    this.columnResizable = false,
    this.controlHitSize = 28,
    // 外框与网格线
    this.border = false,
    this.frame = const ElStyle(border: ElBorder.all(color: Color(0xffd8dce1))),
    this.gridLines = true,
    this.horizontalGridLines,
    this.verticalGridLines,
    this.rowDivider,
    this.columnDivider,
    // 结构面
    this.table = const ElStyle(),
    this.header = const ElStyle(
      bgColor: Color(0xfff6f7f8),
      color: Color(0xff3f4650),
      fontWeight: FontWeight.w600,
      border: ElBorder.only(bottom: ElBorderSide(color: Color(0xffd8dce1))),
    ),
    this.row = const ElStyle(
      border: ElBorder.only(bottom: ElBorderSide(color: Color(0xffe3e6ea))),
      onHover: ElStyle(bgColor: Color(0xfff2f4f6)),
    ),
    this.stripe = false,
    this.stripeRow = const ElStyle(bgColor: Color(0xfffafbfc)),
    this.highlightCurrentRow = true,
    this.currentRow = const ElStyle(bgColor: Color(0xffe8edf3)),
    this.expanded = const ElStyle(
      padding: .symmetric(horizontal: 12, vertical: 12),
      bgColor: Color(0xfffafbfc),
      color: Color(0xff3f4650),
      border: ElBorder.only(bottom: ElBorderSide(color: Color(0xffe3e6ea))),
      onDark: ElStyle(
        bgColor: Color(0xff20242b),
        color: Color(0xffe5e7eb),
        border: ElBorder.only(bottom: ElBorderSide(color: Color(0xff3a4049))),
      ),
    ),
    this.cell = const ElStyle(),
    ElStyle? headerCell,
    ElStyle? draggingHeaderCell,
    ElStyle? groupHeader,
    this.summary = const ElStyle(
      fontWeight: FontWeight.w600,
      border: ElBorder.only(top: ElBorderSide(color: Color(0xffd8dce1))),
    ),
    // 非数据态
    this.empty = const ElStyle(alignment: .center, color: Color(0xff727984)),
    this.emptyHeight,
    this.loading = const ElStyle(alignment: .center, color: Color(0xff727984)),
    this.loadError = const ElStyle(alignment: .center, color: Color(0xffd03050)),
    // 固定列
    this.fixedDividerColor,
    this.fixedDividerWidth = 1,
    this.fixedColumnShadow,
    // 行内控件
    this.selection = const ElStyle(
      width: 14,
      height: 14,
      alignment: .center,
      bgColor: Color(0xffffffff),
      border: ElBorder.all(color: Color(0xffaeb4bd)),
      borderRadius: .all(Radius.circular(2)),
    ),
    this.selectionActive = const ElStyle(
      bgColor: Color(0xff374151),
      border: ElBorder.all(color: Color(0xff374151)),
    ),
    this.sort = const ElStyle(width: 20, height: 10, alignment: .center, color: Color(0xffaeb4bd)),
    this.sortActive = const ElStyle(color: Color(0xff374151)),
    this.expand = const ElStyle(
      width: 28,
      height: 28,
      alignment: .center,
      color: Color(0xff727984),
      cursor: SystemMouseCursors.click,
    ),
    this.resize = const ElStyle(cursor: SystemMouseCursors.resizeColumn),
    this.rowResize = const ElStyle(cursor: SystemMouseCursors.resizeRow),
  }) : _headerCell = headerCell,
       _draggingHeaderCell = draggingHeaderCell,
       _groupHeader = groupHeader;

  // ───────────────────────────── 尺寸与密度 (8) ─────────────────────────────

  /// 数据行默认高度。
  final double rowHeight;

  /// 是否让数据行按最宽松元格内容自动增高；rowHeight 此时作为最小高度。
  ///
  /// 与列虚拟化互斥：行高靠全列实测得出，而列虚拟化只挂载横向窗口内的列。
  /// 为真时底层自动避让，本帧不做列虚拟化（列虚拟化恒按 auto 判据）。
  final bool autoRowHeight;

  /// 表头默认高度；null 表示跟随解析后的数据行高度。
  final double? headerHeight;

  /// 表头与数据单元格默认内边距。
  final EdgeInsetsGeometry cellPadding;

  /// 单元格左右内边距的总和，方向性边距不需要折算为物理左右。
  double get cellHorizontalPadding => cellPadding.horizontal;

  /// 未声明列宽时使用的默认最小列宽。
  final double minColumnWidth;

  /// 行列尺寸调整手柄的默认命中热区。
  final double resizeHitSize;

  /// 未由列或列类型声明时，普通列是否默认允许拖拽调整宽度。
  final bool columnResizable;

  /// 选择、单选等行内控件的命中尺寸，上层可按移动或桌面密度调整。
  final double controlHitSize;

  // ──────────────────────────── 外框与网格线 (7) ────────────────────────────

  /// 是否绘制表格外框；外框外观由 [frame] 决定。
  final bool border;

  /// 表格外框样式（边框线 / 圆角 / 阴影 / 裁切），仅在 [border] 为 true 时绘制。
  final ElStyle frame;

  /// 横纵网格线总开关；方向开关未声明时跟随此值。
  final bool gridLines;

  /// 是否绘制数据行之间的横向网格线；null 跟随 [gridLines]。
  ///
  /// 关闭时摘掉 [row] 与 [expanded] 自带的下边框（表头与合计行的横线属于各自样式，
  /// 不受本开关影响）；[rowDivider] 非 null 时由它接管横线外观。
  final bool? horizontalGridLines;

  /// 是否绘制列之间的纵向网格线；null 跟随 [gridLines]。
  ///
  /// 竖线外观由 [columnDivider] 决定：未声明该样式时即便开关为 true 也不出线
  /// （默认皮肤不画竖线，与历史外观一致）。
  final bool? verticalGridLines;

  /// 横向网格线样式，叠加到每个数据行与展开详情上；null 表示沿用 [row] 与
  /// [expanded] 自带的下边框。
  final ElStyle? rowDivider;

  /// 纵向网格线样式，叠加到每个表头与数据单元格左侧；null 表示不绘制。
  final ElStyle? columnDivider;

  // ────────────────────────────── 结构面 (13) ──────────────────────────────

  /// 表格根节点样式。
  final ElStyle table;

  /// 表头样式。
  final ElStyle header;

  /// 数据行样式，悬停和暗色外观可使用 ElStyle 状态变体。
  final ElStyle row;

  /// 是否为交替数据行绘制斑马纹。
  final bool stripe;

  /// 斑马纹行样式；[stripe] 为 true 时叠加在奇数展示序号的数据行上。
  final ElStyle stripeRow;

  /// 是否绘制当前行高亮；哪一行是当前行仍由 controller 决定。
  final bool highlightCurrentRow;

  /// 当前行高亮时叠加的普通样式；null 表示沿用 [row]。
  final ElStyle? currentRow;

  /// 展开详情区域样式。
  final ElStyle expanded;

  /// 数据单元格样式。
  final ElStyle cell;

  /// 表头单元格样式；未声明时沿用 [cell]。
  ElStyle get headerCell => _headerCell ?? cell;

  /// 拖动换序中的表头表面；未声明时复用表头行背景，确保透明单元格移动后仍有实体底色。
  ElStyle get draggingHeaderCell => _draggingHeaderCell ?? header;

  /// 多级表头中的分组单元格样式；未声明时沿用普通表头外观。
  ElStyle get groupHeader => _groupHeader ?? header;

  /// 固定在底部的合计行样式。
  final ElStyle summary;

  /// 派生样式的显式声明；null 表示沿用上面注释里写明的来源样式。
  final ElStyle? _headerCell;

  /// 见 [draggingHeaderCell]。
  final ElStyle? _draggingHeaderCell;

  /// 见 [groupHeader]。
  final ElStyle? _groupHeader;

  // ──────────────────────────── 非数据态 (4) ────────────────────────────

  /// 空数据区域样式。
  final ElStyle empty;

  /// 空数据区域高度；null 表示使用两倍最小行高。
  final double? emptyHeight;

  /// 加载态外观（蒙层 / 指示条底色与文字）；加载状态本身归业务层，这里只声明外观。
  final ElStyle loading;

  /// 加载失败态外观；同 [loading]，只声明外观。
  final ElStyle loadError;

  // ────────────────────────────── 固定列 (3) ──────────────────────────────

  /// 固定列与滚动列之间的分隔线颜色。
  final Color? fixedDividerColor;

  /// 固定列与滚动列之间的分隔线宽度。
  final double fixedDividerWidth;

  /// 固定列在遮挡侧绘制的阴影。
  final List<BoxShadow>? fixedColumnShadow;

  // ────────────────────────────── 行内控件 (7) ──────────────────────────────

  /// 选择控件样式。
  final ElStyle selection;

  /// 选择控件选中或半选时叠加的普通样式。
  final ElStyle selectionActive;

  /// 排序控件样式。
  final ElStyle sort;

  /// 排序方向激活时叠加的普通样式。
  final ElStyle sortActive;

  /// 展开控件样式。
  final ElStyle expand;

  /// 尺寸调整手柄样式。
  final ElStyle resize;

  /// 行高调整手柄样式。
  final ElStyle rowResize;

  /// 逐字段覆盖本皮肤，返回新实例；基于一份预设做差异微调是最常见的用法。
  ///
  /// 参数三态语义与 `ElStyle.copyWith` 一致：未传参保留原值，显式传 null 置空，
  /// 传值即覆盖。尺寸字段接受任意 `num`（`rowHeight: 32` 与 `32.0` 等价）。
  ElTableStyle copyWith({
    Object? rowHeight = $absent,
    Object? autoRowHeight = $absent,
    Object? headerHeight = $absent,
    Object? cellPadding = $absent,
    Object? minColumnWidth = $absent,
    Object? resizeHitSize = $absent,
    Object? columnResizable = $absent,
    Object? controlHitSize = $absent,
    Object? border = $absent,
    Object? frame = $absent,
    Object? gridLines = $absent,
    Object? horizontalGridLines = $absent,
    Object? verticalGridLines = $absent,
    Object? rowDivider = $absent,
    Object? columnDivider = $absent,
    Object? table = $absent,
    Object? header = $absent,
    Object? row = $absent,
    Object? stripe = $absent,
    Object? stripeRow = $absent,
    Object? highlightCurrentRow = $absent,
    Object? currentRow = $absent,
    Object? expanded = $absent,
    Object? cell = $absent,
    Object? headerCell = $absent,
    Object? draggingHeaderCell = $absent,
    Object? groupHeader = $absent,
    Object? summary = $absent,
    Object? empty = $absent,
    Object? emptyHeight = $absent,
    Object? loading = $absent,
    Object? loadError = $absent,
    Object? fixedDividerColor = $absent,
    Object? fixedDividerWidth = $absent,
    Object? fixedColumnShadow = $absent,
    Object? selection = $absent,
    Object? selectionActive = $absent,
    Object? sort = $absent,
    Object? sortActive = $absent,
    Object? expand = $absent,
    Object? resize = $absent,
    Object? rowResize = $absent,
  }) => ElTableStyle(
    rowHeight: rowHeight == $absent ? this.rowHeight : (rowHeight! as num).toDouble(),
    autoRowHeight: autoRowHeight == $absent ? this.autoRowHeight : autoRowHeight! as bool,
    headerHeight: headerHeight == $absent ? this.headerHeight : (headerHeight as num?)?.toDouble(),
    cellPadding: cellPadding == $absent ? this.cellPadding : cellPadding! as EdgeInsetsGeometry,
    minColumnWidth: minColumnWidth == $absent ? this.minColumnWidth : (minColumnWidth! as num).toDouble(),
    resizeHitSize: resizeHitSize == $absent ? this.resizeHitSize : (resizeHitSize! as num).toDouble(),
    columnResizable: columnResizable == $absent ? this.columnResizable : columnResizable! as bool,
    controlHitSize: controlHitSize == $absent ? this.controlHitSize : (controlHitSize! as num).toDouble(),
    border: border == $absent ? this.border : border! as bool,
    frame: frame == $absent ? this.frame : frame! as ElStyle,
    gridLines: gridLines == $absent ? this.gridLines : gridLines! as bool,
    horizontalGridLines: horizontalGridLines == $absent ? this.horizontalGridLines : horizontalGridLines as bool?,
    verticalGridLines: verticalGridLines == $absent ? this.verticalGridLines : verticalGridLines as bool?,
    rowDivider: rowDivider == $absent ? this.rowDivider : rowDivider as ElStyle?,
    columnDivider: columnDivider == $absent ? this.columnDivider : columnDivider as ElStyle?,
    table: table == $absent ? this.table : table! as ElStyle,
    header: header == $absent ? this.header : header! as ElStyle,
    row: row == $absent ? this.row : row! as ElStyle,
    stripe: stripe == $absent ? this.stripe : stripe! as bool,
    stripeRow: stripeRow == $absent ? this.stripeRow : stripeRow! as ElStyle,
    highlightCurrentRow: highlightCurrentRow == $absent ? this.highlightCurrentRow : highlightCurrentRow! as bool,
    currentRow: currentRow == $absent ? this.currentRow : currentRow as ElStyle?,
    expanded: expanded == $absent ? this.expanded : expanded! as ElStyle,
    cell: cell == $absent ? this.cell : cell! as ElStyle,
    headerCell: headerCell == $absent ? _headerCell : headerCell as ElStyle?,
    draggingHeaderCell: draggingHeaderCell == $absent ? _draggingHeaderCell : draggingHeaderCell as ElStyle?,
    groupHeader: groupHeader == $absent ? _groupHeader : groupHeader as ElStyle?,
    summary: summary == $absent ? this.summary : summary! as ElStyle,
    empty: empty == $absent ? this.empty : empty! as ElStyle,
    emptyHeight: emptyHeight == $absent ? this.emptyHeight : (emptyHeight as num?)?.toDouble(),
    loading: loading == $absent ? this.loading : loading! as ElStyle,
    loadError: loadError == $absent ? this.loadError : loadError! as ElStyle,
    fixedDividerColor: fixedDividerColor == $absent ? this.fixedDividerColor : fixedDividerColor as Color?,
    fixedDividerWidth: fixedDividerWidth == $absent ? this.fixedDividerWidth : (fixedDividerWidth! as num).toDouble(),
    fixedColumnShadow: fixedColumnShadow == $absent ? this.fixedColumnShadow : fixedColumnShadow as List<BoxShadow>?,
    selection: selection == $absent ? this.selection : selection! as ElStyle,
    selectionActive: selectionActive == $absent ? this.selectionActive : selectionActive! as ElStyle,
    sort: sort == $absent ? this.sort : sort! as ElStyle,
    sortActive: sortActive == $absent ? this.sortActive : sortActive! as ElStyle,
    expand: expand == $absent ? this.expand : expand! as ElStyle,
    resize: resize == $absent ? this.resize : resize! as ElStyle,
    rowResize: rowResize == $absent ? this.rowResize : rowResize! as ElStyle,
  );
}

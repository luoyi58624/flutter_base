import 'package:flutter/widgets.dart';

import '../../views/view/semantics/semantics.dart' show ElSemantics;
import '../../views/view/style/style.dart' show ElStyle;
import '../../views/view/style/style_context.dart' show ElStyleContext;
import '../../views/view/view.dart' show ElView;

part 'col.dart';

/// 主轴对齐，对齐官方 `justify`。
enum ElRowJustify { start, end, center, spaceAround, spaceBetween, spaceEvenly }

/// 交叉轴对齐，对齐官方 `align`。
enum ElRowAlign { top, middle, bottom }

/// Element Plus 24 栅格的行。
///
/// 列宽是相对行内容盒的百分比（`span / 24`），一行放不下自动折行；
/// [gutter] 走官方口径——行左右各负 `gutter/2` 外边距、列左右各 `gutter/2`
/// 内边距，两者抵消后首末列仍与容器齐边。
class ElRow extends StatelessWidget {
  const ElRow({
    super.key,
    required this.children,
    this.gutter = 0,
    this.justify = ElRowJustify.start,
    this.align = ElRowAlign.top,
    this.style,
    this.semanticLabel,
  });

  /// 列列表，通常为 [ElCol]
  final List<Widget> children;

  /// 列间距
  final double gutter;

  final ElRowJustify justify;
  final ElRowAlign align;

  final ElStyle? style;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _RowScope(
      gutter: gutter,
      child: ElView(
        semantics: ElSemantics(container: true, label: semanticLabel),
        style: ElStyle(
          width: '100%',
          // 抵消列的内边距，让首末列与行容器齐边
          margin: gutter == 0 ? null : EdgeInsets.symmetric(horizontal: -gutter / 2),
        ).merge(style),
        child: Wrap(alignment: _wrapAlignment, crossAxisAlignment: _wrapCrossAlignment, children: children),
      ),
    );
  }

  WrapAlignment get _wrapAlignment => switch (justify) {
    ElRowJustify.start => WrapAlignment.start,
    ElRowJustify.end => WrapAlignment.end,
    ElRowJustify.center => WrapAlignment.center,
    ElRowJustify.spaceAround => WrapAlignment.spaceAround,
    ElRowJustify.spaceBetween => WrapAlignment.spaceBetween,
    ElRowJustify.spaceEvenly => WrapAlignment.spaceEvenly,
  };

  WrapCrossAlignment get _wrapCrossAlignment => switch (align) {
    ElRowAlign.top => WrapCrossAlignment.start,
    ElRowAlign.middle => WrapCrossAlignment.center,
    ElRowAlign.bottom => WrapCrossAlignment.end,
  };
}

/// 行向列下发 gutter
class _RowScope extends InheritedWidget {
  const _RowScope({required this.gutter, required super.child});

  final double gutter;

  static double gutterOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_RowScope>()?.gutter ?? 0;

  @override
  bool updateShouldNotify(_RowScope oldWidget) => gutter != oldWidget.gutter;
}

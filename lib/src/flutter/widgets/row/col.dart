part of 'index.dart';

/// Element Plus 24 栅格的列。
///
/// **断点语义按 el_ui 的上界口径**（`xs` ≤320、`sm` ≤640、`md` ≤1024、
/// `lg` ≤1920、`xl` ≤2560），取**命中的最小档**，与 element 的 min-width
/// 数值不同：写 `xs: 24, md: 12`，则 300px 用 24、800px 用 12、更宽用 [span]。
///
/// 官方的 `push` / `pull`（相对定位互换列序）未实现，因此不暴露参数。
class ElCol extends StatelessWidget {
  const ElCol({
    super.key,
    this.child,
    this.span = 24,
    this.offset = 0,
    this.xs,
    this.sm,
    this.md,
    this.lg,
    this.xl,
    this.style,
  }) : assert(span >= 0 && span <= 24, 'span 取值 0~24'),
       assert(offset >= 0 && offset <= 24, 'offset 取值 0~24');

  final Object? child;

  /// 占据的栅格数，0 表示不渲染
  final int span;

  /// 左侧间隔的栅格数
  final int offset;

  /// 各断点下的 span 覆盖
  final int? xs;
  final int? sm;
  final int? md;
  final int? lg;
  final int? xl;

  final ElStyle? style;

  @override
  Widget build(BuildContext context) {
    // 读断点即订阅：只有档位翻转才重建本列
    final ctx = ElView.of(context);
    final effective = _spanFor(ctx);
    if (effective <= 0) return const ElView();

    final gutter = _RowScope.gutterOf(context);
    if (offset == 0) return _column(gutter, effective, 0);
    // 原生边距只接收像素，栅格偏移在实际布局约束下折算。
    return LayoutBuilder(
      builder: (context, constraints) =>
          _column(gutter, effective, constraints.maxWidth.isFinite ? constraints.maxWidth * offset / 24 : 0),
    );
  }

  Widget _column(double gutter, int effective, double offsetWidth) => ElView(
    style: ElStyle(
      width: _percent(effective),
      padding: gutter == 0 ? null : EdgeInsets.symmetric(horizontal: gutter / 2),
      margin: offsetWidth == 0 ? null : EdgeInsets.only(left: offsetWidth),
    ).merge(style),
    child: child,
  );

  /// 命中的最小档优先：小屏时 xs..xl 会同时为真，取声明过的最小那个
  int _spanFor(ElStyleContext ctx) {
    if (ctx.xs && xs != null) return xs!;
    if (ctx.sm && sm != null) return sm!;
    if (ctx.md && md != null) return md!;
    if (ctx.lg && lg != null) return lg!;
    if (ctx.xl && xl != null) return xl!;
    return span;
  }

  static String _percent(int span) => '${span / 24 * 100}%';
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 自然尺寸的大标题导航，使用官方 SliverResizingHeader 进行缩放与吸顶。
///
/// 头部最大高度由标题的实际布局测量，不要求业务设置 expandedHeight；
/// 仅标题区域参与过渡，正文仍由后续 Sliver 负责。
class ElSliverLargeTitle extends StatefulWidget {
  /// 创建可收缩至顶部工具栏的大标题。
  const ElSliverLargeTitle({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.centerTitle = false,
    this.fade = false,
    this.snap = false,
    this.toolbarExtent = 56,
    this.largeTitlePadding = const EdgeInsets.fromLTRB(20, 12, 20, 18),
    this.bottom,
    this.bottomPadding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.backgroundColor,
    this.largeTitleStyle,
    this.compactTitleStyle,
  }) : assert(toolbarExtent > 0);

  /// 大小标题共用的文字内容。
  final String title;

  /// 固定工具栏的起始按钮。
  final Widget? leading;

  /// 固定工具栏末端的操作。
  final List<Widget> actions;

  /// 紧凑标题是否居中。
  final bool centerTitle;

  /// 是否改用交叉淡入淡出；false 时大标题缩小淡出。
  final bool fade;

  /// 在首个折叠区间停下时，是否将导航吸附到最近端点。
  final bool snap;

  /// 固定工具栏的主轴高度，不含顶部安全区。
  final double toolbarExtent;

  /// 大标题的自然留白。
  final EdgeInsets largeTitlePadding;

  /// 随大标题一起收起的底部区域，例如搜索框；只挂载一份真实 Widget。
  final Widget? bottom;

  /// 底部区域的自然留白。
  final EdgeInsets bottomPadding;

  /// 导航背景。
  final Color? backgroundColor;

  /// 展开文字样式。
  final TextStyle? largeTitleStyle;

  /// 收起后文字样式。
  final TextStyle? compactTitleStyle;

  @override
  State<ElSliverLargeTitle> createState() => _LargeTitleState();
}

class _LargeTitleState extends State<ElSliverLargeTitle> {
  double? _measuredMax;
  double _bottomHeight = 0;
  ScrollPosition? _position;
  bool _snapping = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (identical(_position, next)) return;
    _position?.isScrollingNotifier.removeListener(_onScrolling);
    _position = next;
    _position?.isScrollingNotifier.addListener(_onScrolling);
  }

  void _onScrolling() {
    if (!widget.snap || _snapping) return;
    final position = _position;
    final max = _measuredMax;
    if (position == null || max == null || !position.hasPixels || !position.hasContentDimensions) return;
    if (position.isScrollingNotifier.value) return;
    final min = MediaQuery.paddingOf(context).top + widget.toolbarExtent;
    final range = max - min;
    if (range <= 0) return;
    final current = position.pixels - position.minScrollExtent;
    if (current <= 0 || current >= range) return;
    final target = current >= range / 2 ? range : 0.0;
    _snapping = true;
    position
        .animateTo(position.minScrollExtent + target, duration: Duration(milliseconds: 180), curve: Curves.easeOutCubic)
        .whenComplete(() => _snapping = false);
  }

  void _recordMax(double extent) {
    if (!mounted || (_measuredMax != null && (extent - _measuredMax!).abs() < 0.01)) return;
    setState(() => _measuredMax = extent);
  }

  void _recordBottom(double extent) {
    if (!mounted || (extent - _bottomHeight).abs() < 0.01) return;
    setState(() => _bottomHeight = extent);
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_onScrolling);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final compactExtent = top + widget.toolbarExtent;
    final largeStyle =
        widget.largeTitleStyle ??
        theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700) ??
        TextStyle(fontSize: 34, fontWeight: FontWeight.w700);
    final compactStyle = widget.compactTitleStyle ?? theme.textTheme.titleMedium ?? TextStyle(fontSize: 18);
    final background = widget.backgroundColor ?? theme.colorScheme.surface;

    // 官方 SliverResizingHeader 从两个原型获取主轴端点高度，业务不输入固定展开高度。
    return SliverResizingHeader(
      minExtentPrototype: SizedBox(height: compactExtent),
      maxExtentPrototype: _NaturalExtentReporter(
        onMeasured: _recordMax,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: compactExtent),
            Padding(
              padding: widget.largeTitlePadding,
              child: Text(widget.title, style: largeStyle),
            ),
            if (widget.bottom != null) SizedBox(height: _bottomHeight),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final full = _measuredMax ?? constraints.maxHeight;
          final range = (full - compactExtent).clamp(0.0, double.infinity);
          final progress = range <= 0 ? 0.0 : ((full - constraints.maxHeight) / range).clamp(0.0, 1.0).toDouble();

          // 只有导航头内部随约束变化，正文 slivers 不重建。
          return ColoredBox(
            color: background,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  height: widget.toolbarExtent,
                  child: NavigationToolbar(
                    centerMiddle: widget.centerTitle,
                    leading: widget.leading,
                    middle: Opacity(
                      opacity: progress,
                      child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: compactStyle),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: widget.actions),
                  ),
                ),
                Positioned(
                  top: compactExtent,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Opacity(
                        opacity: widget.bottom == null ? 1 - progress : (1 - progress * 2).clamp(0.0, 1.0),
                        child: Padding(
                          padding: widget.largeTitlePadding,
                          child: Transform.scale(
                            alignment: Alignment.topLeft,
                            scale: widget.fade ? 1 : 1 - 0.2 * progress,
                            child: Text(widget.title, style: largeStyle),
                          ),
                        ),
                      ),
                      if (widget.bottom != null)
                        Opacity(
                          opacity: (2 - progress * 2).clamp(0.0, 1.0),
                          child: _NaturalExtentReporter(
                            onMeasured: _recordBottom,
                            child: Padding(padding: widget.bottomPadding, child: widget.bottom),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 最大高度原型只测尺寸；变动合并在帧尾，不能从 performLayout 触发 setState。
class _NaturalExtentReporter extends SingleChildRenderObjectWidget {
  const _NaturalExtentReporter({required this.onMeasured, required super.child});

  final ValueChanged<double> onMeasured;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNaturalExtent(onMeasured);

  @override
  void updateRenderObject(BuildContext context, _RenderNaturalExtent renderObject) {
    renderObject.onMeasured = onMeasured;
  }
}

class _RenderNaturalExtent extends RenderProxyBox {
  _RenderNaturalExtent(this.onMeasured);

  ValueChanged<double> onMeasured;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final extent = size.height;
    if (_last != null && (extent - _last!).abs() < 0.01) return;
    _last = extent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onMeasured(extent);
    });
  }
}

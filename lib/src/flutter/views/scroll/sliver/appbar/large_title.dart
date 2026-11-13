import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../commons/theme/index.dart';
import '../../../view/view.dart';

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

  /// 导航背景，缺省读取主题背景色。
  final Color? backgroundColor;

  /// 展开文字样式，缺省为 34 号粗体并读取主题文字色。
  final TextStyle? largeTitleStyle;

  /// 收起后文字样式，缺省为 18 号半粗并读取主题文字色。
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
    // 折叠进度按本头部自己的滚动偏移计算：前面还有刷新头等 Sliver 时，要扣掉它们占用的滚动距离。
    final start = switch (context.findRenderObject()) {
      final RenderSliver sliver => sliver.constraints.precedingScrollExtent,
      _ => position.minScrollExtent,
    };
    final current = position.pixels - start;
    if (current <= 0 || current >= range) return;
    final target = current >= range / 2 ? range : 0.0;
    _snapping = true;
    position
        .animateTo(start + target, duration: Duration(milliseconds: 180), curve: Curves.easeOutCubic)
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
    // 颜色决定头部自身的绘制，在消费点按键读取；未安装主题时背景退回白色，文字沿用环境样式。
    final view = ElView.maybeOf(context);
    final textColor = view?.getVar<Color>(ElTokens.$textColor);
    final top = MediaQuery.paddingOf(context).top;
    final compactExtent = top + widget.toolbarExtent;
    final largeStyle = widget.largeTitleStyle ?? TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: textColor);
    final compactStyle =
        widget.compactTitleStyle ?? TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor);
    final background = widget.backgroundColor ?? view?.getVar<Color>(ElTokens.$bgColor) ?? const Color(0xFFFFFFFF);

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
          // 缩放型标题沿一条连续路径进入固定导航，不在原位置缩小、提前淡出。
          // 非缩放型沿用两份标题的交叉渐变。
          final scale = (compactStyle.fontSize ?? 18) / (largeStyle.fontSize ?? 34);
          final compactTextHeight = (compactStyle.fontSize ?? 18) * (compactStyle.height ?? 1.2);
          final largeTop = compactExtent + widget.largeTitlePadding.top;
          final compactTop = top + (widget.toolbarExtent - compactTextHeight) / 2;
          final dx = (widget.leading == null ? 16.0 : 72.0) - widget.largeTitlePadding.left;
          final direction = Directionality.of(context);
          final endFade = ((progress - .9) / .1).clamp(0.0, 1.0).toDouble();
          // 搜索区先淡出内容，之后才逐步裁掉背景占位；避免文字被高度裁剪切断。
          final titleTravel = (range - _bottomHeight).clamp(0.0, double.infinity);
          final bottomFadeEnd = titleTravel / 4;
          final bottomOpacity = bottomFadeEnd <= 0
              ? 1 - progress
              : (1 - progress * range / bottomFadeEnd).clamp(0.0, 1.0).toDouble();

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
                      opacity: widget.fade ? progress : endFade,
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
                        opacity: widget.fade ? 1 - progress : 1 - endFade,
                        child: Padding(
                          padding: widget.largeTitlePadding,
                          child: Transform.translate(
                            offset: widget.fade
                                ? Offset.zero
                                : Offset(
                                    (direction == TextDirection.rtl ? -dx : dx) * progress,
                                    (compactTop - largeTop) * progress,
                                  ),
                            child: Transform.scale(
                              alignment: direction == TextDirection.rtl ? Alignment.topRight : Alignment.topLeft,
                              scale: widget.fade ? 1 : 1 + (scale - 1) * progress,
                              child: Text(widget.title, style: largeStyle),
                            ),
                          ),
                        ),
                      ),
                      if (widget.bottom != null)
                        Opacity(
                          opacity: bottomOpacity,
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

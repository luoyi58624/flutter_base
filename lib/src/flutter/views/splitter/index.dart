import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';

/// 分栏面板配置。
class ElSplitterPanel {
  const ElSplitterPanel({required this.child, this.size, this.min = 0.0, this.max = 1.0, this.resizable = true})
      : assert(min >= 0 && min <= 1, 'min 是 0~1 的占比'),
        assert(max >= 0 && max <= 1, 'max 是 0~1 的占比');

  final Widget child;

  /// 初始占比 0~1；不传则与其他未声明的面板均分剩余空间
  final double? size;

  /// 占比下限 / 上限
  final double min;
  final double max;

  /// 该面板右（下）侧的分隔条是否可拖动
  final bool resizable;
}

/// 无外观分栏面板。
///
/// 面板宽度用 flex 权重表达，拖动时按「像素增量 ÷ 容器主轴长度」换算成占比增量，
/// 因此不需要 LayoutBuilder 之类的测量层。
class ElSplitterView extends StatefulWidget {
  const ElSplitterView({
    super.key,
    required this.panels,
    this.direction = Axis.horizontal,
    this.barSize = 4,
    this.onResize,
    this.style,
    this.barStyle,
    this.semanticLabel,
  }) : assert(panels.length >= 2, '至少要有两个面板');

  final List<ElSplitterPanel> panels;
  final Axis direction;

  /// 分隔条粗细
  final double barSize;

  /// 拖动结束后回调各面板的最新占比
  final ValueChanged<List<double>>? onResize;

  final ElStyle? style;
  final ElStyle? barStyle;
  final String? semanticLabel;

  @override
  State<ElSplitterView> createState() => _SplitterViewState();
}

class _SplitterViewState extends State<ElSplitterView> {
  late List<double> _weights = _initialWeights();

  @override
  void didUpdateWidget(ElSplitterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 面板数量或声明占比变了才重置，纯内容变化保留用户拖出来的比例
    final sizesChanged =
        widget.panels.length != oldWidget.panels.length ||
            List.generate(widget.panels.length, (i) => widget.panels[i].size).toString() !=
                List.generate(oldWidget.panels.length, (i) => oldWidget.panels[i].size).toString();
    if (sizesChanged) _weights = _initialWeights();
  }

  /// 已声明 size 的面板按声明值，其余均分剩余；总和归一
  List<double> _initialWeights() {
    final declared = widget.panels.where((p) => p.size != null).fold<double>(0, (sum, p) => sum + p.size!);
    final rest = widget.panels
        .where((p) => p.size == null)
        .length;
    final each = rest == 0 ? 0.0 : ((1 - declared) / rest).clamp(0.0, 1.0);
    final weights = [for (final panel in widget.panels) panel.size ?? each];
    final total = weights.fold<double>(0, (sum, w) => sum + w);
    if (total <= 0) return List.filled(widget.panels.length, 1 / widget.panels.length);
    return [for (final w in weights) w / total];
  }

  /// 容器主轴像素长度：拖动时现读自身 render box，免去测量层
  double get _extent {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;
    return widget.direction == Axis.horizontal ? box.size.width : box.size.height;
  }

  /// 把像素增量转成占比，在相邻两个面板之间搬运，受各自 min/max 夹取
  void _drag(int index, double delta) {
    final extent = _extent;
    if (extent <= 0) return;
    final ratio = delta / extent;

    final left = widget.panels[index];
    final right = widget.panels[index + 1];
    final leftNext = (_weights[index] + ratio).clamp(left.min, left.max);
    final rightNext = (_weights[index + 1] - (leftNext - _weights[index])).clamp(right.min, right.max);
    // 右侧被夹住时反推左侧，保证两者之和不变
    final leftFinal = _weights[index] + _weights[index + 1] - rightNext;
    if (leftFinal < left.min || leftFinal > left.max) return;

    setState(() {
      _weights[index] = leftFinal;
      _weights[index + 1] = rightNext;
    });
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.direction == Axis.horizontal;
    final children = <Widget>[];
    for (var i = 0; i < widget.panels.length; i++) {
      children.add(
        Expanded(
          // flex 只接受整数，占比放大后取整即可保住三位有效数字
          flex: (_weights[i] * 10000).round().clamp(1, 10000),
          child: widget.panels[i].child,
        ),
      );
      if (i < widget.panels.length - 1) {
        children.add(_bar(i, horizontal: horizontal, enabled: widget.panels[i].resizable));
      }
    }

    return ElView(
      semantics: ElSemantics(container: true, label: widget.semanticLabel),
      style: const ElStyle(width: '100%').merge(widget.style),
      child: Flex(direction: widget.direction, crossAxisAlignment: .stretch, children: children),
    );
  }

  Widget _bar(int index, {required bool horizontal, required bool enabled}) {
    return ElView(
      event: enabled
          ? ElEvent(
        onHorizontalDragUpdate: horizontal ? (e) => _drag(index, e.delta.dx) : null,
        onVerticalDragUpdate: horizontal ? null : (e) => _drag(index, e.delta.dy),
        onHorizontalDragEnd: horizontal ? (_) => widget.onResize?.call(List.of(_weights)) : null,
        onVerticalDragEnd: horizontal ? null : (_) => widget.onResize?.call(List.of(_weights)),
      )
          : null,
      style: ElStyle(
        width: horizontal ? widget.barSize : null,
        height: horizontal ? null : widget.barSize,
        cursor: !enabled
            ? SystemMouseCursors.basic
            : (horizontal ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.resizeUpDown),
      ).merge(widget.barStyle),
    );
  }
}

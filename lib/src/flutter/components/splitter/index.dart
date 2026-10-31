import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 分栏面板及分隔条外观的公共声明。
class ElSplitter extends StatelessWidget {
  /// 创建分栏配置，拖动和比例维护由具体实现提供。
  const ElSplitter({
    super.key,
    required this.panels,
    this.direction = Axis.horizontal,
    this.barSize = 4,
    this.onResize,
    this.style,
    this.barStyle,
    this.semanticLabel,
  });

  /// 面板内容及初始比例，复用通用 ElSplitterPanel 配置。
  final List<ElSplitterPanel> panels;

  /// 面板排列方向。
  final Axis direction;

  /// 分隔条的逻辑粗细。
  final double barSize;

  /// 调整结束后各面板比例的通知。
  final ValueChanged<List<double>>? onResize;

  /// 根节点样式。
  final ElStyle? style;

  /// 分隔条样式。
  final ElStyle? barStyle;

  /// 分栏区域的辅助名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).splitterBuilder!(context, this);
}

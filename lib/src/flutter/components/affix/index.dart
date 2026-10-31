import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 内容吸附及视口偏移的公共声明。
class ElAffix extends StatelessWidget {
  /// 创建固钉配置，不注册滚动监听。
  const ElAffix({
    super.key,
    required this.child,
    this.offset = 0,
    this.disabled = false,
    this.style,
  });

  /// 固钉内容。
  final Widget child;

  /// 吸附时距离视口主轴首边的逻辑偏移。
  final double offset;

  /// 是否停用吸附行为。
  final bool disabled;

  /// 根节点样式。
  final ElStyle? style;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).affixBuilder!(context, this);
}

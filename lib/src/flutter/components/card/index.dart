import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 卡片内容、加载状态、阴影与可选点击行为的公共声明。
class ElCard extends StatelessWidget {
  /// 创建卡片，品牌提供默认外观及按压反馈，用户 style 最后覆盖。
  const ElCard({super.key, this.child, this.loading = false, this.style, this.event, this.shadowLevel, this.onTap});

  /// 可选卡片内容，标题和其他布局由调用方自行组合。
  final Widget? child;

  /// 加载期间显示指示器、保留内容实例并暂停交互。
  final bool loading;

  /// 覆盖默认外观，包括内边距、圆角、阴影和按压变体。
  final ElStyle? style;

  /// 详细事件与识别配置，onTap 可取消默认点击回调。
  final ElEvent? event;

  /// 阴影档位，省略时无阴影，style.boxShadow 优先。
  final ElLevelType? shadowLevel;

  /// 整卡点击回调，非空时启用默认按压反馈。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ElComponentProvider.of(context).cardBuilder!(context, this);
}

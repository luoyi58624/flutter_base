import 'package:flutter/widgets.dart';

import '../../views/view/event/event.dart' show ElEvent;
import '../../views/view/style/style.dart' show ElStyle;
import '../index.dart' show ElComponentProvider;

/// 承载卡片内容，并提供加载状态与可选点击行为。
class ElCard extends StatelessWidget {
  /// 创建卡片，品牌提供默认外观及按压反馈，用户 style 最后覆盖。
  const ElCard({super.key, this.semanticLabel, this.child, this.loading = false, this.style, this.event, this.onTap});

  /// 区域语义名称，仅命名容器，不替换后代内容。
  final String? semanticLabel;

  /// 可选卡片内容，标题和其他布局由调用方自行组合。
  final Widget? child;

  /// 加载期间显示指示器、保留内容实例并暂停交互。
  final bool loading;

  /// 覆盖默认外观，包括内边距、圆角、阴影和按压变体。
  final ElStyle? style;

  /// 详细事件与识别配置，onTap 可取消默认点击回调。
  final ElEvent? event;

  /// 整卡点击回调，非空时启用默认按压反馈。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.card)(context, this);
}

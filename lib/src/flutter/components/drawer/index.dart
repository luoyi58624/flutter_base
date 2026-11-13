import 'package:flutter/widgets.dart';

import '../../../../dart.dart' show El;
import '../../views/view/event/event.dart';
import '../../views/view/style/style.dart';
import '../../widgets/popup/modal.dart' show showModal;
import '../dialog/index.dart' show ElPopupPlacement;
import '../index.dart';

/// 抽屉服务。
extension ElDrawerExt on El {
  static final _service = ElDrawerService._();

  /// 从屏幕边缘打开抽屉。
  ElDrawerService get drawer => _service;
}

/// 在根导航器打开 ElDrawer；遮罩点击、返回键、Esc 和拖动关闭得到 null。
final class ElDrawerService {
  ElDrawerService._();

  /// 从 placement 指定的边缘打开抽屉，内容里用 `Navigator.pop(context, value)` 返回结果；size 为抽屉宽度或高度。
  Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    Object? title,
    Object? footer,
    ElPopupPlacement placement = .right,
    double? size,
    bool showClose = true,
    bool dismissible = true,
    ElStyle? style,
    String? semanticLabel,
  }) => showModal<T>(
    context,
    dismissible: dismissible,
    label: semanticLabel ?? (title is String ? title : null),
    builder: (close) => ElDrawer(
      title: title,
      footer: footer,
      placement: placement,
      size: size,
      showClose: showClose,
      dismissible: dismissible,
      style: style,
      semanticLabel: semanticLabel,
      onClose: close,
      child: child,
    ),
  );
}

/// 停靠屏幕边缘的抽屉内容，可直接嵌入页面，也可经 el.drawer 以模态打开；外观、遮罩和进退场由品牌实现。
class ElDrawer extends StatelessWidget {
  /// 标题和页脚接受文字或 Widget，正文超出时独立滚动。
  const ElDrawer({
    super.key,
    required this.child,
    this.title,
    this.footer,
    this.placement = .right,
    this.size,
    this.showClose = true,
    this.dismissible = true,
    this.onClose,
    this.style,
    this.event,
    this.semanticLabel,
  });

  /// 正文，保留原 Widget 实例。
  final Widget child;

  /// 可选标题。
  final Object? title;

  /// 正文下方的操作内容。
  final Object? footer;

  /// 停靠的边缘。
  final ElPopupPlacement placement;

  /// 抽屉宽度（左右）或高度（上下），省略时由品牌决定。
  final double? size;

  /// 显示关闭按钮；直接嵌入页面、没有关闭入口时不显示。
  final bool showClose;

  /// 允许遮罩点击、返回键、Esc 和拖动关闭；为假时只能通过按钮关闭。
  final bool dismissible;

  /// 关闭入口与拖动关闭的回调，经 el.drawer 打开时由服务提供；直接嵌入页面时为空。
  final VoidCallback? onClose;

  /// 在品牌默认样式后合并。
  final ElStyle? style;

  /// 面板根节点事件。
  final ElEvent? event;

  /// 辅助技术读取的名称，省略时取文字标题。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.drawer)(context, this);
}

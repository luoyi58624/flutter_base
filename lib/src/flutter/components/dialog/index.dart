import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../dart.dart' show El;
import '../../commons/models.dart' show ElThemeType;
import '../../views/view/event/event.dart';
import '../../views/view/style/style.dart';
import '../../views/view/view.dart' show ElView;
import '../../widgets/popup/modal.dart' show showModal;
import '../input/index.dart' show ElInput;
import '../tokens.dart';
import '../index.dart';

part 'service.dart';

/// 模态内容相对视口的停靠位置。
enum ElPopupPlacement {
  /// 居中展示。
  center,

  /// 贴近底部。
  bottom,

  /// 贴近顶部。
  top,

  /// 从左边进入。
  left,

  /// 从右边进入。
  right,
}

/// 对话框内容声明，可直接嵌入页面，也可经 el.dialog 以模态打开；外观、遮罩和进退场由品牌实现。
class ElDialog extends StatelessWidget {
  /// 居中时为对话框，停靠底部或顶部时为面板；footer 为空且提供 confirmText 时，品牌绘制标准操作按钮。
  const ElDialog({
    super.key,
    required this.child,
    this.title,
    this.footer,
    this.placement = .center,
    this.showClose = false,
    this.dismissible = true,
    this.confirmText,
    this.cancelText,
    this.type = .primary,
    this.onConfirm,
    this.onCancel,
    this.onClose,
    this.style,
    this.event,
    this.semanticLabel,
  });

  /// 正文，可传文字或 Widget。
  final Object child;

  /// 可选标题。
  final Object? title;

  /// 自定义页脚，优先于标准操作按钮。
  final Object? footer;

  /// 停靠位置。
  final ElPopupPlacement placement;

  /// 显示关闭按钮；直接嵌入页面、没有关闭入口时不显示。
  final bool showClose;

  /// 允许遮罩点击、返回键、Esc 和拖动关闭；为假时只能通过按钮关闭。
  final bool dismissible;

  /// 确认按钮文字，提供时品牌绘制标准操作。
  final Object? confirmText;

  /// 取消按钮文字，为空时只有确认按钮。
  final Object? cancelText;

  /// 确认按钮的语义类型，危险操作传 error。
  final ElThemeType type;

  /// 点击确认按钮。
  final VoidCallback? onConfirm;

  /// 点击取消按钮。
  final VoidCallback? onCancel;

  /// 关闭入口与拖动关闭的回调，经 el.dialog 打开时由服务提供；直接嵌入页面时为空。
  final VoidCallback? onClose;

  /// 在品牌默认样式后合并。
  final ElStyle? style;

  /// 面板根节点事件。
  final ElEvent? event;

  /// 辅助技术读取的名称，省略时取文字标题。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.dialog)(context, this);
}

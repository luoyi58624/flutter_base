import 'package:flutter/rendering.dart' show RenderOffstage;
import 'package:flutter/widgets.dart';

import '../../cores/view/event/event.dart' show ElFocusReason;

/// UI 内部共用的焦点请求、可见性检查与焦点原因传递工具。
class FocusUtil {
  FocusUtil._();

  /// 请求焦点、立即提交挂起的焦点变更，并把目标滚动到可见区域。
  ///
  /// 同步提交后，菜单等调用方才能立即读取本次请求后的焦点状态。
  static void requestFocus(FocusNode node) {
    node.requestFocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    final focusContext = node.context;
    if (focusContext == null) return;
    final renderObject = focusContext.findRenderObject();
    if (renderObject == null) return;
    renderObject.showOnScreen(duration: Duration.zero);
  }

  /// 检查节点能否请求焦点且仍位于已挂载、非 Offstage 的渲染分支。
  static bool isVisible(FocusNode node) {
    if (!node.canRequestFocus) return false;
    final context = node.context;
    if (context == null || !context.mounted) return false;
    var active = true;
    assert(() {
      if (context is Element) active = context.debugIsActive;
      return true;
    }());
    if (!active) return false;
    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) return false;
    RenderObject? current = renderObject;
    while (current != null) {
      if (current is RenderOffstage && current.offstage) return false;
      current = current.parent;
    }
    return true;
  }

  /// 按节点身份暂存原因，避免多节点并发请求时原因串味。
  static final Expando<ElFocusReason> _focusReasons = Expando<ElFocusReason>('ElView.focusReason');

  /// 在请求焦点前标记原因；帧末自动清除未被消费的标记，避免影响下次聚焦。
  static void markReason(FocusNode node, ElFocusReason reason) {
    _focusReasons[node] = reason;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_focusReasons[node], reason)) _focusReasons[node] = null;
    });
  }

  /// 读取并清空节点上的焦点原因；没有标记时返回 null。
  static ElFocusReason? takeReason(FocusNode node) {
    final reason = _focusReasons[node];
    _focusReasons[node] = null;
    return reason;
  }
}

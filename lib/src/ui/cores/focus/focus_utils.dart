import 'package:flutter/rendering.dart' show RenderOffstage;
import 'package:flutter/widgets.dart';

import '../view/event/event.dart' show ElFocusReason;

/// 请求焦点、立即提交挂起的焦点变更，并把目标滚动到可见区域。
///
/// 菜单、选择器等控件用显式节点驱动焦点时沿用同一套提交时序：不同步冲刷
/// pending 变更，后续读取 `hasPrimaryFocus` 会读到上一帧的现场。
void requestFocusNode(FocusNode node) {
  node.requestFocus();
  FocusManager.instance.applyFocusChangesIfNeeded();
  final focusContext = node.context;
  if (focusContext == null) return;
  final renderObject = focusContext.findRenderObject();
  if (renderObject == null) return;
  renderObject.showOnScreen(duration: Duration.zero);
}

/// [node] 是否仍位于会参与绘制的 Render 树分支。
///
/// 判定口径：节点有 context 且仍挂载、render 已 attach、祖先链上没有
/// offstage 分支。菜单栏等控件在归还焦点前用它过滤失效目标。
bool focusNodeIsVisible(FocusNode node) {
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

/// 焦点原因暂存：Expando 按节点身份关联，避免多节点并发请求时原因串味。
final Expando<ElFocusReason> _focusReasons = Expando<ElFocusReason>('ElView.focusReason');

/// 在 [node] 即将 requestFocus 前标记原因，供视图层生成 focus 事件。
///
/// 帧末自清：请求未落地（被别的目标抢占、节点提前卸载）时不把原因留给
/// 下一次聚焦。
void markFocusReason(FocusNode node, ElFocusReason reason) {
  _focusReasons[node] = reason;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (identical(_focusReasons[node], reason)) _focusReasons[node] = null;
  });
}

/// 读取并清空 [node] 上标记的原因；没有标记时返回 null。
ElFocusReason? takeFocusReason(FocusNode node) {
  final reason = _focusReasons[node];
  _focusReasons[node] = null;
  return reason;
}

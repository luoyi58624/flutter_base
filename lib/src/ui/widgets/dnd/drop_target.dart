import 'package:flutter/widgets.dart';

import 'drag_session.dart';

/// 悬停在 target 上的候选载荷（builder 的样式映射输入）。
@immutable
class ElDropCandidate<T> {
  /// 创建。
  const ElDropCandidate({required this.data, required this.accepted});

  /// 拖拽中的载荷。
  final T data;

  /// canAccept 判定结果（false = 悬停中但不可投放，builder 可映射"拒收"样式）。
  final bool accepted;
}

/// 投放明细（onDrop 回调入参）。
@immutable
class ElDropDetails {
  /// 创建。
  const ElDropDetails({required this.globalPosition, required this.localPosition});

  /// 松手位置（全局坐标）。
  final Offset globalPosition;

  /// 松手位置（target 本地坐标）。
  final Offset localPosition;
}

/// 数据投放目标：接收 `ElDraggable<T>` 同泛型的载荷。
///
/// ```dart
/// ElDropTarget<String>(
///   canAccept: (id) => id != 'locked',
///   onDrop: (id, details) => list.add(id),
///   builder: (context, candidate) => ElView(
///     style: ElStyle(
///       border: .all(color: switch (candidate) {
///         null => grey,                                // 空闲
///         ElDropCandidate(accepted: true) => green,    // 可投放
///         _ => red,                                    // 拒收
///       }),
///     ),
///     child: content,
///   ),
/// )
/// ```
///
/// 命中：MetaData(translucent) 挂进命中路径，嵌套 target 最深者优先、被上层
/// 内容遮挡时不误中；ghost 预览层全程 `pointerEvents: none` 不挡命中。
class ElDropTarget<T extends Object> extends StatefulWidget {
  /// 创建投放目标。
  const ElDropTarget({
    super.key,
    required this.builder,
    this.canAccept,
    this.onDrop,
    this.onEnter,
    this.onLeave,
    this.onMove,
  });

  /// 内容构造器：candidate 非 null = 匹配类型的拖拽正悬停在本 target 上。
  final Widget Function(BuildContext context, ElDropCandidate<T>? candidate) builder;

  /// 载荷可否投放（null = 类型匹配即收）。false 时仍产生 candidate
  /// （accepted: false）与 enter/leave 回调，但 drop 不派发。
  final bool Function(T data)? canAccept;

  /// 投放回调（仅 accepted 时）。
  final void Function(T data, ElDropDetails details)? onDrop;

  /// 拖拽进入。
  final void Function(T data)? onEnter;

  /// 拖拽离开（含会话取消 / drop 后收尾）。
  final void Function(T data)? onLeave;

  /// 拖拽在本 target 上移动（local 坐标见 [ElDropDetails.localPosition] 同源换算）。
  final void Function(T data, Offset localPosition)? onMove;

  @override
  State<ElDropTarget<T>> createState() => _DropTargetState<T>();
}

class _DropTargetState<T extends Object> extends State<ElDropTarget<T>> {
  late final DropTargetBinding _binding = DropTargetBinding(
    matches: (data) => data is T,
    onEnter: _handleEnter,
    onLeave: _handleLeave,
    onMove: _handleMove,
    onDrop: _handleDrop,
  );

  ElDropCandidate<T>? _candidate;

  bool _accepts(T data) => widget.canAccept?.call(data) ?? true;

  Offset _toLocal(Offset global) {
    final ro = context.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) return ro.globalToLocal(global);
    return global;
  }

  void _handleEnter(Object? data) {
    final typed = data as T;
    setState(() => _candidate = ElDropCandidate<T>(data: typed, accepted: _accepts(typed)));
    widget.onEnter?.call(typed);
  }

  void _handleLeave(Object? data) {
    if (_candidate == null) return;
    if (mounted) {
      setState(() => _candidate = null);
    } else {
      _candidate = null;
    }
    widget.onLeave?.call(data as T);
  }

  void _handleMove(Object? data, Offset globalPosition) {
    widget.onMove?.call(data as T, _toLocal(globalPosition));
  }

  bool _handleDrop(Object? data, Offset globalPosition) {
    final typed = data as T;
    if (!_accepts(typed)) return false;
    widget.onDrop?.call(typed, ElDropDetails(globalPosition: globalPosition, localPosition: _toLocal(globalPosition)));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // translucent：挂进命中路径但不吞不挡（内容自身的命中语义不变）。
    return MetaData(
      metaData: _binding,
      behavior: HitTestBehavior.translucent,
      child: widget.builder(context, _candidate),
    );
  }
}

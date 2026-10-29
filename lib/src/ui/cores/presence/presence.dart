import 'dart:async' show Timer;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// [ElPresence] 当前所处的存在相位。
enum ElPresencePhase {
  /// 挂载首帧（仅一帧）：builder 以入场前样式渲染，下一帧翻到 [visible]
  /// 触发 transition——经典 enter-from 模式。样式层入场也可改用
  /// `ElStyle.starting`（无需感知相位）。
  entering,

  /// 常驻可见。
  visible,

  /// 退场中：`visible: false` 后子树保持挂载并以退场样式渲染，
  /// [ElPresence.exitDuration] 计满后摘树。
  exiting,
}

/// 进出场编排器：解决「条件渲染的子树一消失就被摘树，退场动画无处播放」。
///
/// ```dart
/// ElPresence(
///   visible: show,
///   exitDuration: const Duration(milliseconds: 200),
///   builder: (context, phase) => ElView(
///     style: ElStyle(
///       opacity: phase == ElPresencePhase.visible ? 1.0 : 0.0,
///       transitions: [.all(Duration(milliseconds: 200))],
///     ),
///     child: 'hello',
///   ),
/// )
/// ```
///
/// 行为：
/// - `visible` 翻 false：子树**不摘**，相位切 [ElPresencePhase.exiting]（builder
///   以退场样式重建 → transition 播出），[exitDuration] 计满摘树并回调 [onExited]；
/// - 退场中途翻回 true：取消摘树，相位回 [ElPresencePhase.visible]（transition
///   从当前插值续回，无跳变）；
/// - 挂载首帧相位为 [ElPresencePhase.entering]（仅一帧）；不需要相位式入场时
///   直接返回同一 widget 即可，或改用 `ElStyle.starting` 全声明式入场；
/// - `visible: false` 且退场完成时 build 输出空盒（零尺寸）。
///
/// [exitDuration] 与退场 transition 的时长解耦（框架无法感知任意后代的过渡
/// 何时结束），调用方保证 ≥ 最长退场动画时长。
class ElPresence extends StatefulWidget {
  /// 创建进出场编排器。
  const ElPresence({
    super.key,
    required this.visible,
    required this.builder,
    this.exitDuration = const Duration(milliseconds: 300),
    this.onExited,
  });

  /// 目标可见性。翻转驱动进出场相位。
  final bool visible;

  /// 子树构造器：按当前相位映射样式。
  final Widget Function(BuildContext context, ElPresencePhase phase) builder;

  /// 退场保活时长（`visible: false` 后延迟摘树的时间），应 ≥ 最长退场动画。
  final Duration exitDuration;

  /// 退场完成（子树已摘）回调。中途重新可见不触发。
  final VoidCallback? onExited;

  @override
  State<ElPresence> createState() => _PresenceState();
}

class _PresenceState extends State<ElPresence> {
  late bool _mounted = widget.visible;
  late ElPresencePhase _phase = ElPresencePhase.entering;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    if (_mounted) _scheduleEnterFlip();
  }

  /// entering 只维持一帧：首帧以入场前样式提交，下一帧翻 visible 触发过渡。
  void _scheduleEnterFlip() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _phase != ElPresencePhase.entering) return;
      setState(() => _phase = ElPresencePhase.visible);
    });
  }

  @override
  void didUpdateWidget(ElPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _exitTimer?.cancel();
      _exitTimer = null;
      if (_mounted) {
        // 退场中途返场：从当前插值续回。
        _phase = ElPresencePhase.visible;
      } else {
        _mounted = true;
        _phase = ElPresencePhase.entering;
        _scheduleEnterFlip();
      }
    } else if (_mounted) {
      _phase = ElPresencePhase.exiting;
      _exitTimer?.cancel();
      _exitTimer = Timer(widget.exitDuration, () {
        if (!mounted) return;
        setState(() => _mounted = false);
        widget.onExited?.call();
      });
    }
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.shrink();
    return widget.builder(context, _phase);
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter_base/src/ui/cores/view/view.dart';
import 'package:flutter_base/src/ui/cores/view/render/render_view.dart' show ElRenderView, CascadeBridgeChanges;
import 'package:flutter_base/src/ui/cores/view/style/style.dart';
import 'drag_session.dart';

/// ghost 跟手壳（会话内部件）：监听 [DndSession.ghostPosition]，把 global
/// 坐标换算到所在 overlay 层本地后经 paint-only transform 平移预览内容。
///
/// 全程 `pointerEvents: none`：ghost 不遮 drop 命中、不抢
/// hover（阶段一 pointer-events 的闭环消费点）。
class GhostFollower extends StatefulWidget {
  /// 创建。[child] 为用户 ghostBuilder 产物。
  const GhostFollower({super.key, required this.child, this.source});

  /// 原拖拽源的样式捕获点；保留跨 Overlay 的文字、主题与断点继承。
  final BuildContext? source;

  /// 预览内容。
  final Widget child;

  @override
  State<GhostFollower> createState() => _GhostFollowerState();
}

class _GhostFollowerState extends State<GhostFollower> {
  Offset _local = Offset.zero;

  @override
  void initState() {
    super.initState();
    DndSession.instance.ghostPosition.addListener(_onPosition);
    // 首帧位置：build 前 render 未挂，postFrame 对齐一次。
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPosition());
  }

  @override
  void dispose() {
    DndSession.instance.ghostPosition.removeListener(_onPosition);
    super.dispose();
  }

  void _onPosition() {
    if (!mounted) return;
    final global = DndSession.instance.ghostPosition.value;
    final ro = Overlay.of(context).context.findRenderObject();
    // 始终相对 Overlay 原点换算，避免把幽灵上一帧的位移重复累加。
    final local = (ro is RenderBox && ro.attached && ro.hasSize) ? ro.globalToLocal(global) : global;
    if (local == _local) return;
    setState(() => _local = local);
  }

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ElStyle(pointerEvents: ElPointerEvents.none, transform: ElTransform.translate(_local.dx, _local.dy)),
      child: widget.source == null ? widget.child : _GhostCascade(from: widget.source!, child: widget.child),
    );
  }
}

// 官方 OverlayEntry 不继承源 render 级联；只在幽灵内补齐原来的差量样式桥接。
class _GhostCascade extends StatefulWidget {
  const _GhostCascade({required this.from, required this.child});
  final BuildContext from;
  final Widget child;

  @override
  State<_GhostCascade> createState() => _GhostCascadeState();
}

class _GhostCascadeState extends State<_GhostCascade> {
  ElRenderView? _source;
  CascadeBridgeChanges? _changes;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    if (widget.from.mounted) {
      final render = widget.from.findRenderObject();
      _source = render is ElRenderView ? render : widget.from.findAncestorRenderObjectOfType<ElRenderView>();
      _changes = _source?.ensureCascadeBridgeChanges();
      _changes?.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted || _pending) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _pending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pending = false;
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _changes?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null || !source.attached) return widget.child;
    final mount = context.findAncestorRenderObjectOfType<ElRenderView>();
    final a = source.committedResolvedStyle;
    final h = mount?.committedResolvedStyle;
    final at = a.inheritedText;
    final ab = a.inheritedBox;
    final needText = !identical(at, h?.inheritedText);
    return ElView(
      themeMode: source.effectiveThemeMode != mount?.effectiveThemeMode ? source.effectiveThemeMode : null,
      breakpoint: source.effectiveBreakpoint != mount?.effectiveBreakpoint ? source.effectiveBreakpoint : null,
      style: ElStyle(
        textDirection: ab.textDirection != h?.inheritedBox.textDirection ? ab.textDirection : null,
        iconSize: ab.iconSize != h?.inheritedBox.iconSize ? ab.iconSize : null,
        iconColor: ab.iconColor != h?.inheritedBox.iconColor ? ab.iconColor : null,
        color: needText ? at.color : null,
        fontSize: needText ? at.fontSize : null,
        fontWeight: needText ? at.fontWeight : null,
        fontStyle: needText ? at.fontStyle : null,
        fontFamily: needText ? at.fontFamily : null,
        fontFamilyFallback: needText ? at.fontFamilyFallback : null,
        lineHeight: needText ? at.lineHeight : null,
        letterSpacing: needText ? at.letterSpacing : null,
        wordSpacing: needText ? at.wordSpacing : null,
        fontFeatures: needText ? at.fontFeatures : null,
        fontVariations: needText ? at.fontVariations : null,
        textAlign: needText ? at.textAlign : null,
        textBaseline: needText ? at.textBaseline : null,
        leadingDistribution: needText ? at.leadingDistribution : null,
        textShadow: needText ? at.textShadow : null,
        textGradient: needText ? at.textGradient : null,
        decorationColor: needText ? at.decorationColor : null,
        decorationStyle: needText ? at.decorationStyle : null,
        decorationThickness: needText ? at.decorationThickness : null,
      ),
      child: widget.child,
    );
  }
}

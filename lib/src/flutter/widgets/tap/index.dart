import 'package:flutter_base/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

part 'ripple.dart';

part 'ripple_painter.dart';

/// 按 React Native TouchableOpacity 的时序提供透明度反馈的通用按钮。
class ElFadeTap extends StatefulWidget {
  /// 创建淡化按钮；首次按下立即变淡，重新移入用 150ms，释放用 250ms 恢复。
  const ElFadeTap({
    super.key,
    this.style,
    required this.onPressed,
    required this.child,
    this.disabled = false,
    this.semanticLabel,
  });

  /// 点击、键盘或辅助技术激活时执行。
  final VoidCallback? onPressed;

  /// 按钮内容，支持 Widget、文本及 ElView 的混排内容。
  final Object? child;

  /// 是否禁用交互和反馈。
  final bool disabled;

  /// 辅助技术使用的按钮名称。
  final String? semanticLabel;

  /// 按钮外观，onTap.opacity 可覆写按压透明度。
  final ElStyle? style;

  @override
  State<ElFadeTap> createState() => _FadeTapState();
}

class _FadeTapState extends State<ElFadeTap> {
  bool _pressed = false;
  bool _returning = false;

  void _down(ElEventDetails event) {
    setState(() {
      _pressed = true;
      _returning = event.originalEvent is PointerMoveEvent;
    });
  }

  void _release(ElEventDetails event) {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  void didUpdateWidget(ElFadeTap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // RN 在禁用或常态透明度改变时恢复，避免保留旧的按压目标。
    if (widget.disabled != oldWidget.disabled || widget.style?.opacity != oldWidget.style?.opacity) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    var style = const ElStyle(
      transition: [.field(ElTransitionField.opacity, Duration(milliseconds: 250), _FadeCurve())],
    ).merge(widget.style);
    // 透明度统一由事件目标控制，避免 onTap 先启动旧时长的过渡；其他按压样式照常级联。
    final tapStyle = style.onTap;
    if (tapStyle?.opacity != null) {
      style = style.copyWith(onTap: null).copyWith(onTap: tapStyle!.copyWith(opacity: null));
    }
    // 进入时长依赖原始事件，静态 onTap 变体无法区分首次按下与移回；帧间插值仍交给样式引擎。
    if (_pressed) {
      style = style.copyWith(
        opacity: widget.style?.onTap?.opacity ?? 0.2,
        transition:
            widget.style?.onTap?.transition ??
            [
              ElTransition.field(
                ElTransitionField.opacity,
                _returning ? const Duration(milliseconds: 150) : Duration.zero,
                const _FadeCurve(),
              ),
            ],
      );
    }
    return ElButtonView(
      onPressed: widget.onPressed,
      disabled: widget.disabled,
      semanticLabel: widget.semanticLabel,
      style: style,
      event: ElEvent(
        config: ElEventConfig(delayTouchUp: Duration.zero),
        onTapDown: _down,
        onTapUp: _release,
        onTapCancel: _release,
      ),
      child: widget.child,
    );
  }
}

class _FadeCurve extends Curve {
  const _FadeCurve();

  // 精确对应 RN Easing.inOut(Easing.quad)，Flutter 的同名曲线是贝塞尔近似。
  @override
  double transformInternal(double t) => t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);
}

/// 按压时触发缩放效果的通用按钮
class ElScaleTap extends ElButtonView {
  ElScaleTap({
    super.key,
    ElStyle? style,
    required super.onPressed,
    required super.child,
    super.disabled = false,
    super.semanticLabel,
  }) : super(
         style: const ElStyle(
           transition: [.field(ElTransitionField.transform, Duration(milliseconds: 100), Curves.easeOut)],
           onTap: ElStyle(transform: ElTransform.scale(0.95)),
         ).merge(style),
       );
}

/// 悬停时浅色高亮、按下时从落点扩散 Material 2 波纹的通用按钮。
class ElRippleTap extends StatefulWidget {
  /// 创建波纹按钮，反馈颜色跟随当前文本色，裁剪跟随 [style] 及直接子 [ElView] 的圆角和路径。
  const ElRippleTap({
    super.key,
    required this.onPressed,
    required this.child,
    this.disabled = false,
    this.semanticLabel,
    this.style,
    this.focusNode,
  });

  /// 点击、键盘或辅助技术激活时执行。
  final VoidCallback? onPressed;

  /// 按钮内容，支持 Widget、文本及 ElView 的混排内容。
  final Object? child;

  /// 是否禁用交互和反馈。
  final bool disabled;

  /// 辅助技术使用的按钮名称。
  final String? semanticLabel;

  /// 按钮的盒模型、文本及状态样式。
  final ElStyle? style;

  /// 可选焦点节点，键盘激活行为由 ElButtonView 统一处理。
  final FocusNode? focusNode;

  @override
  State<ElRippleTap> createState() => _RippleTapState();
}

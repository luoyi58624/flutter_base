/// 参照：D:/project/html/my-ui/packages/vue/components/Progress.vue；packages/core/my-ui.js:5700-5788；my-ui.css:1596-1760。
library;

import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../flutter/commons/theme/index.dart' show ElThemeContextExt;
import '../../../../flutter/components/progress/index.dart' show ElProgress, ElProgressValue;
import '../../../../flutter/views/view/semantics/semantics.dart' show ElSemantics;
import '../../../../flutter/views/view/style/style.dart' show ElStyle;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../commons/icons.dart' show ElMobileIcons;
import '../../cores/common.dart';

/// 将公共完成量、状态和读数交给原移动端进度皮肤。
Widget progressBuilder(BuildContext context, ElProgress component) => Progress(
  value: component.value,
  buffer: component.buffer,
  max: component.max,
  type: component.shape == .circle ? .circle : .line,
  status: switch (component.status) {
    .normal => .normal,
    .success => .success,
    .warning => .warning,
    .error => .error,
  },
  label: component.semanticLabel,
  showText: component.showText,
  textBuilder: component.textBuilder == null
      ? null
      : (context, value) => component.textBuilder!(
          context,
          ElProgressValue(value: value.value, max: value.max, percentage: value.percentage),
        ),
  style: component.style,
);

/// 进度展示方式。
enum ProgressType {
  /// 条形。
  line,

  /// 环形。
  circle,
}

/// 进度语义状态。
enum ProgressStatus {
  /// 主题色。
  normal,

  /// 成功色和勾号。
  success,

  /// 警告色。
  warning,

  /// 危险色和叉号。
  error,
}

/// 默认插槽收到的归一化数值，对应Web的value/max/percentage。
@immutable
class ProgressValue {
  const ProgressValue._(this.value, this.max, this.percentage);

  /// 合法完成量，不确定时为null。
  final double? value;

  /// 合法总量。
  final double max;

  /// 0..100的完成比例，不确定时为0。
  final double percentage;
}

/// 进度默认插槽，可显示任意读数。
typedef ProgressTextBuilder = Widget Function(BuildContext context, ProgressValue value);

/// 支持缓冲、确定/不确定值和自定义读数的进度条或圆环。
class Progress extends HookWidget {
  /// 局部进度颜色。
  static const $color = 'progress.color';

  /// 局部轨道颜色。
  static const $track = 'progress.track';

  /// 局部缓冲颜色。
  static const $bufferColor = 'progress.bufferColor';

  /// 局部轨道粗细。
  static const $thickness = 'progress.thickness';

  /// 局部圆环尺寸。
  static const $size = 'progress.size';

  /// 非有限value进入不确定状态，非法max回退100。
  const Progress({
    super.key,
    this.value,
    this.buffer,
    this.max = 100,
    this.type = ProgressType.line,
    this.status = ProgressStatus.normal,
    this.label = '进度',
    this.showText = true,
    this.textBuilder,
    this.style,
  });

  /// 当前完成量。
  final double? value;

  /// 缓冲量，只在确定状态显示且不会小于完成量。
  final double? buffer;

  /// 总量。
  final double max;

  /// 条形或环形。
  final ProgressType type;

  /// 状态配色。
  final ProgressStatus status;

  /// 辅助名称。
  final String? label;

  /// 是否展示读数，隐藏时保留插槽实例。
  final bool showText;

  /// 对应带value/max/percentage的默认插槽。
  final ProgressTextBuilder? textBuilder;

  /// 公共声明提供的根样式，数值宽高同步参与圆环内容的尺寸计算。
  final ElStyle? style;
  @override
  Widget build(BuildContext context) {
    final vars = ElView.maybeOf(context);
    final t = context.elTheme, reduced = reducedMotion(context), circle = type == ProgressType.circle;
    final total = max.isFinite && max > 0 ? max : 100.0;
    final amount = value?.isFinite == true ? value!.clamp(0.0, total) : null;
    final ratio = (amount ?? 0) / total;
    final buffered = amount != null && buffer?.isFinite == true ? buffer!.clamp(amount, total) / total : null;
    final indefinite = amount == null, percentage = (ratio * 100).round();
    final color =
        vars?.getVar<Color>($color) ??
        switch (status) {
          ProgressStatus.normal => t.primary,
          ProgressStatus.success => t.success,
          ProgressStatus.warning => t.warning,
          ProgressStatus.error => t.error,
        };
    final track = vars?.getVar<Color>($track) ?? t.fill,
        bufferColor = vars?.getVar<Color>($bufferColor) ?? Color.lerp(track, color, .28)!;
    double? dimension(Object? value) => value is num && value.isFinite && value > 0 ? value.toDouble() : null;
    final width = circle ? dimension(style?.width) : null;
    final height = circle ? dimension(style?.height) : null;
    final fallback = vars?.getVar<num>($size)?.toDouble() ?? 96;
    final size = math.min(width ?? height ?? fallback, height ?? width ?? fallback);
    final thickness = vars?.getVar<num>($thickness)?.toDouble() ?? 6;
    final clock = useAnimationController(duration: Duration(milliseconds: circle ? 1000 : 1400));
    useEffect(() {
      if (indefinite && !reduced) {
        clock.repeat();
      } else {
        clock.stop();
        clock.value = 0;
      }
      return null;
    }, [indefinite, reduced, circle]);
    final fillMotion = useAnimationController(initialValue: ratio, duration: const Duration(milliseconds: 200));
    final bufferMotion = useAnimationController(
      initialValue: buffered ?? ratio,
      duration: const Duration(milliseconds: 200),
    );
    useEffect(() {
      if (reduced) {
        fillMotion.value = ratio;
        bufferMotion.value = buffered ?? ratio;
      } else {
        fillMotion.animateTo(ratio, duration: const Duration(milliseconds: 200), curve: Curves.ease);
        bufferMotion.animateTo(buffered ?? ratio, duration: const Duration(milliseconds: 200), curve: Curves.ease);
      }
      return null;
    }, [ratio, buffered, reduced]);
    final textKey = useMemoized(() => GlobalKey());
    final data = ProgressValue._(amount, total, ratio * 100);
    final glyph = status == ProgressStatus.success
        ? ElMobileIcons.check
        : status == ProgressStatus.error
        ? ElMobileIcons.x
        : null;
    final readout = Offstage(
      offstage: !showText,
      child: KeyedSubtree(
        key: textKey,
        child: ExcludeSemantics(
          child: ElView(
            style:
                textStyle(
                  context,
                  circle ? (indefinite ? 12 : 16) : 13,
                  circle && !indefinite ? t.fontWeightAction : t.fontWeight,
                  color: circle ? t.textColor : t.textSecondary,
                  height: 1.6,
                ).merge(
                  ElStyle(
                    minWidth: circle ? null : 42,
                    minHeight: 21,
                    alignment: Alignment.center,
                    fontFeatureSettings: const [FontFeature.tabularFigures()],
                  ),
                ),
            child:
                textBuilder?.call(context, data) ??
                (glyph == null
                    ? '$percentage%'
                    : ElView(
                        style: ElStyle(iconSize: circle ? size * .28 : 18, iconColor: color),
                        child: glyph,
                      )),
          ),
        ),
      ),
    );
    final visual = AnimatedBuilder(
      animation: Listenable.merge([clock, fillMotion, bufferMotion]),
      builder: (context, _) => CustomPaint(
        painter: _ProgressPainter(
          ratio: fillMotion.value,
          buffer: buffered == null ? null : bufferMotion.value,
          indeterminate: indefinite,
          circle: circle,
          phase: clock.value,
          reduced: reduced,
          color: color,
          track: track,
          bufferColor: bufferColor,
          thickness: thickness,
        ),
      ),
    );
    final result = ElView(
      semantics: ElSemantics(
        container: true,
        properties: SemanticsProperties(
          // TODO(parity): Flutter不确定进度使用loadingSpinner角色，Web保持progressbar；待平台读屏验收。
          role: indefinite ? SemanticsRole.loadingSpinner : SemanticsRole.progressBar,
          label: label,
          minValue: indefinite ? null : '0',
          maxValue: indefinite ? null : '100',
          value: indefinite ? '进行中' : '$percentage%',
          hint: buffered == null ? null : '已缓冲 ${(buffered * 100).round()}%',
        ),
      ),
      style: ElStyle(width: circle ? size : '100%', height: circle ? size : null).merge(style),
      child: circle
          ? Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                visual,
                Positioned.fill(child: Center(child: readout)),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: SizedBox(height: thickness, child: visual),
                ),
                if (showText) const SizedBox(width: 12),
                readout,
              ],
            ),
    );
    return circle ? inline(result) : result;
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.ratio,
    required this.buffer,
    required this.indeterminate,
    required this.circle,
    required this.phase,
    required this.reduced,
    required this.color,
    required this.track,
    required this.bufferColor,
    required this.thickness,
  });
  final double ratio, phase, thickness;
  final double? buffer;
  final bool indeterminate, circle, reduced;
  final Color color, track, bufferColor;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    if (circle) {
      // TODO(parity): CSS圆环在0值/缓冲隐藏时另有200ms opacity过渡，目前仅插值弧长。
      final extent = math.min(size.width, size.height);
      final center = size.center(Offset.zero), radius = extent * .44, stroke = thickness * extent / 100;
      final rect = Rect.fromCircle(center: center, radius: radius);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track;
      canvas.drawCircle(center, radius, paint);
      paint.strokeCap = StrokeCap.round;
      if (buffer != null && buffer! > 0) {
        paint.color = bufferColor;
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * buffer!, false, paint);
      }
      if (indeterminate || ratio > 0) {
        paint.color = color;
        canvas.drawArc(
          rect,
          -math.pi / 2 + (indeterminate && !reduced ? phase * math.pi * 2 : 0),
          math.pi * 2 * (indeterminate ? .28 : ratio),
          false,
          paint,
        );
      }
    } else {
      final radius = Radius.circular(size.height / 2);
      final bounds = RRect.fromRectAndRadius(Offset.zero & size, radius);
      paint.color = track;
      canvas.drawRRect(bounds, paint);
      canvas.save();
      canvas.clipRRect(bounds);
      void fill(double start, double length, Color color) {
        if (length <= 0) return;
        paint.color = color;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(start * size.width, 0, length * size.width, size.height), radius),
          paint,
        );
      }

      if (buffer != null) fill(0, buffer!, bufferColor);
      fill(
        indeterminate ? (reduced ? .32 : -.352 + 1.696 * Curves.easeInOut.transform(phase)) : 0,
        indeterminate ? .32 : ratio,
        color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      ratio != old.ratio ||
      buffer != old.buffer ||
      indeterminate != old.indeterminate ||
      circle != old.circle ||
      phase != old.phase ||
      reduced != old.reduced ||
      color != old.color ||
      track != old.track ||
      bufferColor != old.bufferColor ||
      thickness != old.thickness;
}

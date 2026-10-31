/// 参照：D:/project/html/my-ui/packages/vue/components/Progress.vue；packages/core/my-ui.js:5700-5788；my-ui.css:1596-1760。
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';
import '../../cores/glyph.dart';

/// 进度展示方式。
enum MyProgressType {
  /// 条形。
  line,

  /// 环形。
  circle,
}

/// 进度语义状态。
enum MyProgressStatus {
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
class MyProgressValue {
  const MyProgressValue._(this.value, this.max, this.percentage);

  /// 合法完成量，不确定时为null。
  final double? value;

  /// 合法总量。
  final double max;

  /// 0..100的完成比例，不确定时为0。
  final double percentage;
}

/// 进度默认插槽，可显示任意读数。
typedef MyProgressTextBuilder = Widget Function(
  BuildContext context,
  MyProgressValue value,
);

/// 支持缓冲、确定/不确定值和自定义读数的进度条或圆环。
class MyProgress extends HookWidget {
  /// 局部进度颜色。
  static const $color = 'my.progress.color';

  /// 局部轨道颜色。
  static const $track = 'my.progress.track';

  /// 局部缓冲颜色。
  static const $bufferColor = 'my.progress.bufferColor';

  /// 局部轨道粗细。
  static const $thickness = 'my.progress.thickness';

  /// 局部圆环尺寸。
  static const $size = 'my.progress.size';

  /// 非有限value进入不确定状态，非法max回退100。
  const MyProgress({
    super.key,
    this.value,
    this.buffer,
    this.max = 100,
    this.type = MyProgressType.line,
    this.status = MyProgressStatus.normal,
    this.label = '进度',
    this.showText = true,
    this.textBuilder,
  });

  /// 当前完成量。
  final double? value;

  /// 缓冲量，只在确定状态显示且不会小于完成量。
  final double? buffer;

  /// 总量。
  final double max;

  /// 条形或环形。
  final MyProgressType type;

  /// 状态配色。
  final MyProgressStatus status;

  /// 辅助名称。
  final String label;

  /// 是否展示读数，隐藏时保留插槽实例。
  final bool showText;

  /// 对应带value/max/percentage的默认插槽。
  final MyProgressTextBuilder? textBuilder;
  @override
  Widget build(BuildContext context) {
    final vars = ElView.maybeOf(context);
    final t = context.elTheme,
        reduced = myReducedMotion(context),
        circle = type == MyProgressType.circle;
    final total = max.isFinite && max > 0 ? max : 100.0;
    final amount = value?.isFinite == true ? value!.clamp(0.0, total) : null;
    final ratio = (amount ?? 0) / total;
    final buffered = amount != null && buffer?.isFinite == true
        ? buffer!.clamp(amount, total) / total
        : null;
    final indefinite = amount == null, percentage = (ratio * 100).round();
    final color =
        vars?.getVar<Color>($color) ??
        switch (status) {
          MyProgressStatus.normal => t.primary,
          MyProgressStatus.success => t.success,
          MyProgressStatus.warning => t.warning,
          MyProgressStatus.error => t.error,
        };
    final track = vars?.getVar<Color>($track) ?? t.fill,
        bufferColor = vars?.getVar<Color>($bufferColor) ?? Color.lerp(track, color, .28)!;
    final size = vars?.getVar<num>($size)?.toDouble() ?? 96,
        thickness = vars?.getVar<num>($thickness)?.toDouble() ?? 6;
    final clock = useAnimationController(
      duration: Duration(milliseconds: circle ? 1000 : 1400),
    );
    useEffect(() {
      if (indefinite && !reduced) {
        clock.repeat();
      } else {
        clock.stop();
        clock.value = 0;
      }
      return null;
    }, [indefinite, reduced, circle]);
    final fillMotion = useAnimationController(
      initialValue: ratio,
      duration: const Duration(milliseconds: 200),
    );
    final bufferMotion = useAnimationController(
      initialValue: buffered ?? ratio,
      duration: const Duration(milliseconds: 200),
    );
    useEffect(() {
      if (reduced) {
        fillMotion.value = ratio;
        bufferMotion.value = buffered ?? ratio;
      } else {
        fillMotion.animateTo(
          ratio,
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
        );
        bufferMotion.animateTo(
          buffered ?? ratio,
          duration: const Duration(milliseconds: 200),
          curve: Curves.ease,
        );
      }
      return null;
    }, [ratio, buffered, reduced]);
    final textKey = useMemoized(() => GlobalKey());
    final data = MyProgressValue._(amount, total, ratio * 100);
    final glyph = status == MyProgressStatus.success
        ? 'check'
        : status == MyProgressStatus.error
        ? 'x'
        : null;
    final readout = Offstage(
      offstage: !showText,
      child: KeyedSubtree(
        key: textKey,
        child: ExcludeSemantics(
          child: ElView(
            style:
                myTextStyle(
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
                        style: ElStyle(
                          width: circle ? size * .28 : 18,
                          height: circle ? size * .28 : 18,
                          color: color,
                        ),
                        child: MyGlyph(
                          name: glyph,
                          size: circle ? size * .28 : 18,
                        ),
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
          role: indefinite
              ? SemanticsRole.loadingSpinner
              : SemanticsRole.progressBar,
          label: label,
          minValue: indefinite ? null : '0',
          maxValue: indefinite ? null : '100',
          value: indefinite ? '进行中' : '$percentage%',
          hint: buffered == null ? null : '已缓冲 ${(buffered * 100).round()}%',
        ),
      ),
      style: ElStyle(
        width: circle ? size : '100%',
        height: circle ? size : null,
      ),
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
    return circle ? myInline(result) : result;
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
      final center = size.center(Offset.zero),
          radius = size.width * .44,
          stroke = thickness * size.width / 100;
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
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              start * size.width,
              0,
              length * size.width,
              size.height,
            ),
            radius,
          ),
          paint,
        );
      }

      if (buffer != null) fill(0, buffer!, bufferColor);
      fill(
        indeterminate
            ? (reduced
                  ? .32
                  : -.352 + 1.696 * Curves.easeInOut.transform(phase))
            : 0,
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

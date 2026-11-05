import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

import '../../flutter/commons/theme/index.dart' show ElThemeContextExt;
import '../../flutter/views/view/style/style.dart';
import '../../flutter/views/view/view.dart';

/// 两端选择控件共用的轻量视觉，交互和语义始终由公共声明负责。
@internal
class ElChoiceVisual extends StatelessWidget {
  /// 创建固定结构的选择标记，换绑只更新样式与绘制参数。
  const ElChoiceVisual({
    super.key,
    required this.checked,
    required this.disabled,
    required this.mobile,
    this.radio = false,
    this.indeterminate = false,
    this.label,
  });

  /// 当前是否选中。
  final bool checked;

  /// 是否禁用交互。
  final bool disabled;

  /// 是否使用移动端尺寸与触摸间距。
  final bool mobile;

  /// 是否绘制单选标记。
  final bool radio;

  /// 是否绘制半选标记。
  final bool indeterminate;

  /// 由公共声明提供的可见文案。
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = context.elTheme;
    final selected = checked || indeterminate;
    final side = mobile ? 20.0 : 16.0;
    final gap = mobile ? 12.0 : 8.0;
    final focusVisible = !mobile && !disabled && (ElView.maybeOf(context)?.hasFocusVisible ?? false);
    final mark = radio
        ? ElView(
            style: ElStyle(
              width: side * .43,
              height: side * .43,
              borderRadius: BorderRadius.circular(side),
              backgroundColor: theme.primaryText,
            ),
          )
        : CustomPaint(
            size: Size.square(side * .7),
            painter: _CheckboxMark(color: theme.primaryText, indeterminate: indeterminate),
          );
    return ElView(
      style: ElStyle(heightFactor: 1, opacity: disabled ? .5 : 1, userSelect: .none),
      child: Row(
        mainAxisSize: .min,
        children: [
          ElView(
            style: ElStyle(padding: EdgeInsets.all(gap)),
            child: ElView(
              style: ElStyle(
                width: side,
                height: side,
                alignment: .center,
                borderRadius: BorderRadius.circular(radio ? side : (mobile ? 4 : 3)),
                backgroundColor: selected ? theme.primary : theme.cardColor,
                border: ElBorder.all(borderWidth: 1.5, borderColor: selected ? theme.primary : theme.borderColor),
                outline: focusVisible
                    ? ElOutline(outlineWidth: 2, outlineColor: theme.primary, outlineOffset: 2)
                    : null,
                transition: const [
                  ElTransition.fields(
                    {ElTransitionField.backgroundColor, ElTransitionField.border},
                    Duration(milliseconds: 150),
                    Curves.ease,
                  ),
                ],
                onHover: mobile || disabled
                    ? null
                    : ElStyle(border: ElBorder.all(borderWidth: 1.5, borderColor: theme.primary)),
              ),
              child: ElView(
                style: ElStyle(
                  opacity: selected ? 1 : 0,
                  transition: const [ElTransition.field(ElTransitionField.opacity, Duration(milliseconds: 150))],
                ),
                child: mark,
              ),
            ),
          ),
          if (label != null)
            Flexible(
              child: ElView(
                style: ElStyle(
                  color: selected ? theme.primary : theme.textRegular,
                  fontSize: 14,
                  padding: EdgeInsetsDirectional.only(end: gap),
                ),
                child: label,
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckboxMark extends CustomPainter {
  _CheckboxMark({required this.color, required this.indeterminate});

  final Color color;
  final bool indeterminate;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.shortestSide * .14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (indeterminate) {
      canvas.drawLine(Offset(size.width * .18, size.height * .5), Offset(size.width * .82, size.height * .5), paint);
      return;
    }
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .15, size.height * .5)
        ..lineTo(size.width * .4, size.height * .75)
        ..lineTo(size.width * .85, size.height * .25),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CheckboxMark oldDelegate) =>
      color != oldDelegate.color || indeterminate != oldDelegate.indeterminate;
}

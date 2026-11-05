/// 参照：D:/project/html/my-ui/packages/vue/components/Divider.vue；packages/core/my-ui.js:1682-1703；my-ui.css:4103-4153。
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../../flutter/commons/theme/index.dart' show ElThemeContextExt;
import '../../../../../flutter/views/view/semantics/semantics.dart' show ElSemantics;
import '../../../../../flutter/views/view/style/style.dart' show ElBorder, ElBorderSide, ElBorderStyle, ElStyle;
import '../../../../../flutter/views/view/view.dart' show ElView;
import '../../../cores/common.dart';

/// 带文字分割线的对齐位置。
enum DividerAlign {
  /// 起始侧固定24px线段。
  start,

  /// 两侧线段等长。
  center,

  /// 末尾侧固定24px线段。
  end,
}

/// 1px水平或竖向分割线，默认插槽只在水平模式显示。
class Divider extends StatelessWidget {
  /// 局部分隔线颜色。
  static const $color = 'divider.color';

  /// 局部分隔线两侧间距。
  static const $spacing = 'divider.spacing';

  /// 局部竖向分隔线高度。
  static const $height = 'divider.height';

  /// 虚线保留与实线相同的厚度，颜色默认读取专用分隔线变量。
  const Divider({super.key, this.vertical = false, this.align = DividerAlign.center, this.dashed = false, this.child});

  /// 是否竖向。
  final bool vertical;

  /// 插槽对齐。
  final DividerAlign align;

  /// 是否虚线。
  final bool dashed;

  /// 默认说明插槽。
  final Object? child;
  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    final vars = ElView.maybeOf(context);
    final side = ElBorderSide(
      borderWidth: 1,
      borderColor: vars?.getVar<Color>($color) ?? t.dividerColor,
      borderStyle: dashed ? ElBorderStyle.dashed : ElBorderStyle.solid,
    );
    Widget line() => ElView(
      style: ElStyle(
        height: vertical ? '100%' : 1,
        width: vertical ? 1 : '100%',
        border: vertical ? ElBorder.only(borderLeft: side) : ElBorder.only(borderTop: side),
      ),
    );
    // TODO(parity): 当前Flutter SemanticsRole无separator/orientation，用中文hint表达方向，需平台读屏验收。
    return ElView(
      semantics: ElSemantics(container: true, hint: vertical ? '垂直分隔线' : '水平分隔线'),
      style: textStyle(context, 13, t.fontWeight, color: t.textSecondary, height: 1.6).merge(
        ElStyle(
          width: vertical ? 1 : '100%',
          height: vertical ? vars?.getVar<num>($height)?.toDouble() ?? 13 : null,
          margin: vertical
              ? EdgeInsets.symmetric(horizontal: vars?.getVar<num>($spacing)?.toDouble() ?? 12)
              : EdgeInsets.symmetric(vertical: vars?.getVar<num>($spacing)?.toDouble() ?? 20),
        ),
      ),
      child: vertical || child == null
          ? line()
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxLabel = math.max(0.0, constraints.maxWidth - 24 - (align == DividerAlign.center ? 0 : 24));
                return Row(
                  children: [
                    if (align == DividerAlign.start) SizedBox(width: 24, child: line()) else Expanded(child: line()),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxLabel),
                      child: buildContent(child),
                    ),
                    const SizedBox(width: 12),
                    if (align == DividerAlign.end) SizedBox(width: 24, child: line()) else Expanded(child: line()),
                  ],
                );
              },
            ),
    );
  }
}

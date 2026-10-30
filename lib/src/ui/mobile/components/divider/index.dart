/// 参照：D:/project/html/my-ui/packages/vue/components/Divider.vue；packages/core/my-ui.js:1682-1703；my-ui.css:4103-4153。
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';
import '../../cores/theme.dart';

/// 带文字分割线的对齐位置。
enum MyDividerAlign {
  /// 起始侧固定24px线段。
  start,

  /// 两侧线段等长。
  center,

  /// 末尾侧固定24px线段。
  end,
}

/// 1px水平或竖向分割线，默认插槽只在水平模式显示。
class MyDivider extends StatelessWidget {
  /// dashed保留与实线相同的厚度，变量通过MyTheme覆写。
  const MyDivider({
    super.key,
    this.vertical = false,
    this.align = MyDividerAlign.center,
    this.dashed = false,
    this.child,
  });

  /// 是否竖向。
  final bool vertical;

  /// 插槽对齐。
  final MyDividerAlign align;

  /// 是否虚线。
  final bool dashed;

  /// 默认说明插槽。
  final Object? child;
  @override
  Widget build(BuildContext context) {
    final t = MyTheme.of(context);
    final side = ElBorderSide(
      width: 1,
      color: t.dividerColor ?? t.border,
      style: dashed ? ElBorderStyle.dashed : ElBorderStyle.solid,
    );
    Widget line() => ElView(
      style: ElStyle(
        height: vertical ? '100%' : 1,
        width: vertical ? 1 : '100%',
        border: vertical ? ElBorder.only(left: side) : ElBorder.only(top: side),
      ),
    );
    // TODO(parity): 当前Flutter SemanticsRole无separator/orientation，用中文hint表达方向，需平台读屏验收。
    return ElView(
      semantics: ElSemantics(
        container: true,
        hint: vertical ? '垂直分隔线' : '水平分隔线',
      ),
      style:
          myTextStyle(
            context,
            13,
            t.fontWeight,
            color: t.textSecondary,
            height: 1.6,
          ).merge(
            ElStyle(
              width: vertical ? 1 : '100%',
              height: vertical ? t.dividerHeight ?? 13 : null,
              margin: vertical
                  ? EdgeInsets.symmetric(horizontal: t.dividerSpacing ?? 12)
                  : EdgeInsets.symmetric(vertical: t.dividerSpacing ?? 20),
            ),
          ),
      child: vertical || child == null
          ? line()
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxLabel = math.max(
                  0.0,
                  constraints.maxWidth -
                      24 -
                      (align == MyDividerAlign.center ? 0 : 24),
                );
                return Row(
                  children: [
                    if (align == MyDividerAlign.start)
                      SizedBox(width: 24, child: line())
                    else
                      Expanded(child: line()),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxLabel),
                      child: myContent(child),
                    ),
                    const SizedBox(width: 12),
                    if (align == MyDividerAlign.end)
                      SizedBox(width: 24, child: line())
                    else
                      Expanded(child: line()),
                  ],
                );
              },
            ),
    );
  }
}

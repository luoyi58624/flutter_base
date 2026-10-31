/// 参照：D:/project/html/my-ui/packages/vue/components/Skeleton.vue；packages/core/my-ui.js:2210-2237；my-ui.css:3807-3855。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';
import '../../cores/theme.dart';

/// 保留正文实例的加载骨架，加载中退出焦点和语义树。
class MySkeleton extends StatelessWidget {
  /// rows遵守Web floor(rows)||3，再限制到1..10。
  const MySkeleton({
    super.key,
    this.loading = true,
    this.rows = 3,
    this.avatar = false,
    this.label = '内容加载中',
    this.child,
  });

  /// 是否显示骨架。
  final bool loading;

  /// 正文行数，0和NaN回退3，有限值向下取整。
  final num rows;

  /// 是否显示42px头像。
  final bool avatar;

  /// 加载时的辅助说明。
  final String label;

  /// 加载结束的正文，加载期间仍保留实例。
  final Widget? child;
  int get _rowCount {
    if (rows.isNaN) return 3;
    if (rows == double.infinity) return 10;
    if (rows == double.negativeInfinity) return 1;
    final count = rows.floor();
    return (count == 0 ? 3 : count).clamp(1, 10);
  }

  @override
  Widget build(BuildContext context) {
    final t = MyTheme.of(context);
    Widget block(Object width, double height, [double radius = 6]) => ElView(
      style: ElStyle(
        width: width,
        height: height,
        backgroundColor: t.fill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          ElView(
            semantics: ElSemantics(
              container: true,
              properties: SemanticsProperties(
                role: SemanticsRole.loadingSpinner,
                label: label,
                liveRegion: true,
              ),
            ),
            style: ElStyle(
              padding: const EdgeInsets.symmetric(vertical: 12),
              animation: myReducedMotion(context)
                  ? const []
                  : [
                      ElAnimation(
                        animationDuration: const Duration(milliseconds: 1500),
                        animationTimingFunction: Curves.easeInOut,
                        animationIterationCount: double.infinity,
                        keyframes: {
                          0: const ElStyle(opacity: 1),
                          50: const ElStyle(opacity: .45),
                          100: const ElStyle(opacity: 1),
                        },
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: avatar ? 14 : 0,
              children: [
                if (avatar) block(42, 42, 999),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block('42%', 18),
                      // CSS普通块的相邻margin取较大值：标题18与正文12合并为18。
                      for (var i = 0; i < _rowCount; i++) ...[
                        SizedBox(height: i == 0 ? 18 : 12),
                        block(i == _rowCount - 1 ? '66%' : '100%', 13),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ExcludeFocus(
          excluding: loading,
          child: TickerMode(
            enabled: !loading,
            child: Offstage(
              offstage: loading,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

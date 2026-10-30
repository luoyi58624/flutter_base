/// 参照：D:/project/html/my-ui/packages/vue/components/Loading.vue；packages/core/my-ui.js:1377-1394；my-ui.css:3755-3805。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_base/ui.dart';

import '../cores/common.dart';
import '../cores/glyph.dart';

/// Web 的三档指示器尺寸。
enum MyLoadingSize {
  /// 16px，用于按钮。
  small(16),

  /// 默认24px。
  medium(24),

  /// 32px。
  large(32);

  const MyLoadingSize(this.pixels);

  /// CSS对应的边长。
  final double pixels;
}

/// 本地SVG圆弧加载指示，可见说明通过child提供。
class MyLoading extends StatelessWidget {
  /// label在没有默认插槽时用于播报。
  const MyLoading({
    super.key,
    this.size = MyLoadingSize.medium,
    this.label = '加载中',
    this.child,
  });

  /// 图标尺寸档位。
  final MyLoadingSize size;

  /// 无可见说明时的名称。
  final String label;

  /// 默认插槽中的可见说明。
  final Object? child;
  @override
  Widget build(BuildContext context) => ElView(
    semantics: ElSemantics(
      container: true,
      properties: SemanticsProperties(
        role: SemanticsRole.loadingSpinner,
        liveRegion: true,
        label: child == null ? label : null,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: child == null ? 0 : 9,
      children: [
        ExcludeSemantics(
          child: ElView(
            style: ElStyle(
              width: size.pixels,
              height: size.pixels,
              animations: myReducedMotion(context)
                  ? const []
                  : [
                      ElAnimation(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.linear,
                        iterationCount: double.infinity,
                        keyframes: {
                          0: ElStyle(transform: ElTransform.rotate(0)),
                          100: ElStyle(
                            transform: ElTransform.rotate(6.283185307179586),
                          ),
                        },
                      ),
                    ],
            ),
            child: MyGlyph(spinner: true, size: size.pixels),
          ),
        ),
        if (child != null)
          ElView(
            style: const ElStyle(fontSize: 13, lineHeight: 1.5),
            child: child,
          ),
      ],
    ),
  );
}

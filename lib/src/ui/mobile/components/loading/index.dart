/// 参照：D:/project/html/my-ui/packages/vue/components/Loading.vue；packages/core/my-ui.js:1377-1394；my-ui.css:3755-3805。
library;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../../../flutter/components/loading_indicator/index.dart' show ElLoadingIndicator;
import '../../../../flutter/views/view/semantics/semantics.dart' show ElSemantics;
import '../../../../flutter/views/view/style/style.dart' show ElAnimation, ElStyle, ElTransform;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../commons/icons.dart' show ElMobileIcons;
import '../../cores/common.dart';

/// 使用既有移动端圆弧承接公共加载指示声明。
Widget loadingIndicatorBuilder(BuildContext context, ElLoadingIndicator component) =>
    Loading(extent: component.size, label: component.semanticLabel, style: component.style, child: component.child);

/// Web 的三档指示器尺寸。
enum LoadingSize {
  /// 16px，用于按钮。
  small(16),

  /// 默认24px。
  medium(24),

  /// 32px。
  large(32);

  const LoadingSize(this.pixels);

  /// CSS对应的边长。
  final double pixels;
}

/// 本地SVG圆弧加载指示，可见说明通过child提供。
class Loading extends StatelessWidget {
  /// label在没有默认插槽时用于播报。
  const Loading({super.key, this.size = LoadingSize.medium, this.extent, this.label = '加载中', this.style, this.child});

  /// 图标尺寸档位。
  final LoadingSize size;

  /// 数值尺寸优先于内部尺寸档位。
  final double? extent;

  /// 无可见说明时的名称。
  final String? label;

  /// 公共声明提供的根样式。
  final ElStyle? style;

  /// 默认插槽中的可见说明。
  final Object? child;
  @override
  Widget build(BuildContext context) {
    final pixels = extent?.isFinite == true && extent! > 0 ? extent! : size.pixels;
    return ElView(
      style: ElStyle(iconSize: pixels).merge(style),
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
                animation: reducedMotion(context)
                    ? const []
                    : [
                        ElAnimation(
                          animationDuration: const Duration(milliseconds: 800),
                          animationTimingFunction: Curves.linear,
                          animationIterationCount: double.infinity,
                          keyframes: {
                            0: ElStyle(transform: ElTransform.rotate(0)),
                            100: ElStyle(transform: ElTransform.rotate(6.283185307179586)),
                          },
                        ),
                      ],
              ),
              child: ElMobileIcons.loading,
            ),
          ),
          if (child != null) ElView(style: const ElStyle(fontSize: 13, lineHeight: 1.5), child: child),
        ],
      ),
    );
  }
}

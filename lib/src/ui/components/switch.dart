import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 公共开关声明，外观、值绑定和交互由全局组件主题提供。
class ElSwitch extends StatelessWidget {
  /// 创建开关；Element 实现也支持祖先表单字段提供值。
  const ElSwitch({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.activeContent,
    this.inactiveContent,
    this.activeActionContent,
    this.inactiveActionContent,
    this.disabled = false,
    this.loading = false,
    this.height,
    this.gap,
    this.widthAspect,
    this.slide = true,
    this.style,
    this.trackStyle,
    this.focusNode,
    this.event,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一'),
       assert(height == null || height > 0, 'height 必须大于 0'),
       assert(gap == null || gap >= 0, 'gap 不能为负数'),
       assert(widthAspect == null || widthAspect > 0, 'widthAspect 必须大于 0');

  /// 初始开关值，组件重建时同步新的值。
  final bool? value;

  /// 外部双向绑定，生命周期由调用方管理。
  final ValueNotifier<bool>? modelValue;

  /// 开关值变化时回调；为空不等于禁用。
  final ValueChanged<bool>? onChanged;

  /// 开启时的轨道色，接受 Color 或颜色 token。
  final Color? activeColor;

  /// 关闭时的轨道色，接受 Color 或颜色 token。
  final Color? inactiveColor;

  /// 轨道内开启态内容，接受文本、图标或 Widget。
  final Object? activeContent;

  /// 轨道内关闭态内容，接受文本、图标或 Widget。
  final Object? inactiveContent;

  /// 滑块内开启态内容，加载时由加载指示替代。
  final Object? activeActionContent;

  /// 滑块内关闭态内容，加载时由加载指示替代。
  final Object? inactiveActionContent;

  /// 禁止用户切换与焦点请求。
  final bool disabled;

  /// 显示加载指示并暂时阻止用户切换。
  final bool loading;

  /// 显式轨道高度，优先于尺寸档。
  final double? height;

  /// 滑块与轨道边缘的间距，未指定时使用品牌默认值。
  final double? gap;

  /// 轨道最小宽高比，轨道内容可进一步撑宽。
  final double? widthAspect;

  /// 是否启用滑块切换动画，false 时直接切换到目标位置。
  final bool slide;

  /// 在主题根样式之后合并的用户样式。
  final ElStyle? style;

  /// 在主题轨道样式之后合并的用户样式。
  final ElStyle? trackStyle;

  /// 外部焦点节点，节点由调用方拥有。
  final FocusNode? focusNode;

  /// 用户事件，沿用底层默认动作与 preventDefault 规则。
  final ElEvent? event;

  /// 辅助技术读取的开关名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => ElComponentProvider.of(context).switchBuilder!(context, this);
}

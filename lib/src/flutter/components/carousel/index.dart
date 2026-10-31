import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';

/// 轮播指示器的位置。
enum ElCarouselIndicator {
  /// 指示器覆盖内容。
  inside,

  /// 指示器排列在内容之外。
  outside,

  /// 隐藏指示器。
  none,
}

/// 轮播箭头的显示时机。
enum ElCarouselArrow {
  /// 始终显示箭头。
  always,

  /// 悬停时显示箭头。
  hover,

  /// 隐藏箭头。
  never,
}

/// 轮播指示器的激活方式。
enum ElCarouselTrigger {
  /// 悬停切换。
  hover,

  /// 点击切换。
  click,
}

/// 轮播公共声明。
class ElCarousel extends StatelessWidget {
  /// 创建轮播公共声明。
  const ElCarousel({
    super.key,
    this.value,
    this.modelValue,
    this.onChanged,
    required this.children,
    this.height = 300,
    this.autoplay = true,
    this.interval = const Duration(seconds: 3),
    this.loop = true,
    this.direction = Axis.horizontal,
    this.indicatorPosition = ElCarouselIndicator.inside,
    this.indicatorTrigger = ElCarouselTrigger.hover,
    this.arrow = ElCarouselArrow.hover,
    this.pauseOnHover = true,
    this.duration = const Duration(milliseconds: 300),
    this.style,
    this.semanticLabel,
  }) : assert(value == null || modelValue == null, 'value 与 modelValue 互斥'),
       assert(children.length > 0, 'children 不能为空'),
       assert(height > 0, 'height 必须大于 0');

  /// 普通值输入，具体同步由品牌实现处理。
  final int? value;

  /// 外部双向模型，生命周期由调用方管理。
  final ValueNotifier<int>? modelValue;

  /// 模型变化通知。
  final ValueChanged<int>? onChanged;

  /// 轮播内容列表。
  final List<Widget> children;

  /// 内容区域的逻辑高度。
  final double height;

  /// 启用自动切换。
  final bool autoplay;

  /// 自动切换间隔。
  final Duration interval;

  /// 允许首尾循环。
  final bool loop;

  /// 轮播方向。
  final Axis direction;

  /// 指示器位置。
  final ElCarouselIndicator indicatorPosition;

  /// 指示器的切换触发方式。
  final ElCarouselTrigger indicatorTrigger;

  /// 箭头的显示时机。
  final ElCarouselArrow arrow;

  /// 悬停时暂停自动切换。
  final bool pauseOnHover;

  /// 页面切换动画时长。
  final Duration duration;

  /// 组件根样式。
  final ElStyle? style;

  /// 辅助技术读取的组件名称。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).carouselBuilder!(context, this);
}

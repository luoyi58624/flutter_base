# Carousel

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/carousel` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElCarousel | `carouselBuilder` |

辅助类型：`ElCarouselIndicator`、`ElCarouselArrow`、`ElCarouselTrigger`。

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElCarousel | value | `int?` | 普通值输入，具体同步由品牌实现处理。 |
| ElCarousel | modelValue | `ValueNotifier<int>?` | 外部双向模型，生命周期由调用方管理。 |
| ElCarousel | onChanged | `ValueChanged<int>?` | 模型变化通知。 |
| ElCarousel | children | `List<Widget>` | 轮播内容列表。 |
| ElCarousel | height | `double` | 内容区域的逻辑高度。 |
| ElCarousel | autoplay | `bool` | 启用自动切换。 |
| ElCarousel | interval | `Duration` | 自动切换间隔。 |
| ElCarousel | loop | `bool` | 允许首尾循环。 |
| ElCarousel | direction | `Axis` | 轮播方向。 |
| ElCarousel | indicatorPosition | `ElCarouselIndicator` | 指示器位置。 |
| ElCarousel | indicatorTrigger | `ElCarouselTrigger` | 指示器的切换触发方式。 |
| ElCarousel | arrow | `ElCarouselArrow` | 箭头的显示时机。 |
| ElCarousel | pauseOnHover | `bool` | 悬停时暂停自动切换。 |
| ElCarousel | duration | `Duration` | 页面切换动画时长。 |
| ElCarousel | style | `ElStyle?` | 组件根样式。 |
| ElCarousel | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

页模型使用 int，首项语义索引为零；默认初始化、范围钳制、定时器和切换动画均由品牌实现。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。

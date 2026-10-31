# Timeline

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/timeline` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElTimeline | `timelineBuilder` |
| ElTimelineItem | `timelineItemBuilder` |

辅助类型：`ElTimelineNodeSize`、`ElTimelinePlacement`。

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElTimeline | children | `List<Widget>` | 时间线成员列表。 |
| ElTimeline | style | `ElStyle?` | 组件根样式。 |
| ElTimeline | semanticLabel | `String?` | 辅助技术读取的组件名称。 |
| ElTimelineItem | child | `Object?` | 事件正文内容。 |
| ElTimelineItem | timestamp | `Object?` | 事件时间戳内容。 |
| ElTimelineItem | placement | `ElTimelinePlacement` | 时间戳相对正文的位置。 |
| ElTimelineItem | hideTimestamp | `bool` | 隐藏时间戳。 |
| ElTimelineItem | type | `ElThemeType?` | 节点的语义颜色类型。 |
| ElTimelineItem | color | `Color?` | 显式节点颜色，优先于 type。 |
| ElTimelineItem | size | `ElTimelineNodeSize` | 节点的语义尺寸。 |
| ElTimelineItem | hollow | `bool` | 使用空心节点。 |
| ElTimelineItem | icon | `Object?` | 节点图标内容。 |
| ElTimelineItem | style | `ElStyle?` | 组件根样式。 |
| ElTimelineItem | nodeStyle | `ElStyle?` | 时间线节点样式。 |
| ElTimelineItem | timestampStyle | `ElStyle?` | 时间戳样式。 |
| ElTimelineItem | contentStyle | `ElStyle?` | 正文区域样式。 |

ElTimelineNodeSize 是节点自身 normal/large 语义选项，不是 Element 全局尺寸档；首末项上下文、连线和节点绘制由品牌实现。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。

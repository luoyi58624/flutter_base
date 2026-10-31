# Progress

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/progress` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElProgressColorStop | 只保存配置的数据类 |
| ElProgressValue | 只保存配置的数据类 |
| ElProgress | `progressBuilder` |

辅助类型：`ElProgressShape`、`ElProgressStatus`、`ElProgressTextBuilder`。

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElProgressColorStop | percentage | `double` | 使用该颜色的百分比上界。 |
| ElProgressColorStop | color | `Color` | 该区间采用的实际颜色。 |
| ElProgressValue | value | `double?` | 完成量，null 表示不确定进度。 |
| ElProgressValue | max | `double` | 读数采用的总量。 |
| ElProgressValue | percentage | `double` | 完成比例的百分数。 |
| ElProgress | shape | `ElProgressShape` | 由命名构造确定的进度形态。 |
| ElProgress | percentage | `double?` | 直接指定 0 至 100 的完成百分比，和 value 互斥。 |
| ElProgress | value | `double?` | 以 max 为总量的当前完成量，和 percentage 互斥。 |
| ElProgress | buffer | `double?` | 缓冲完成量，与 value 使用相同单位。 |
| ElProgress | max | `double` | value 和 buffer 的总量基准。 |
| ElProgress | status | `ElProgressStatus` | 进度的语义状态。 |
| ElProgress | showText | `bool` | 显示品牌默认读数或自定义读数插槽。 |
| ElProgress | textBuilder | `ElProgressTextBuilder?` | 根据品牌实现提供的进度快照构建读数。 |
| ElProgress | semanticLabel | `String?` | 辅助技术读取的进度名称。 |
| ElProgress | strokeLinecap | `StrokeCap` | 进度笔画两端的形状。 |
| ElProgress | colorStops | `List<ElProgressColorStop>?` | 按百分比上界排列的分段颜色。 |
| ElProgress | style | `ElStyle?` | 组件根样式。 |
| ElProgress | strokeWidth | `double` | 直线条或圆环的笔画宽度。 |
| ElProgress | color | `Color?` | 进度颜色，分段色标可由品牌实现优先处理。 |
| ElProgress | trackColor | `Color?` | 进度轨道颜色。 |
| ElProgress | width | `double` | 圆环与仪表盘的逻辑直径。 |
| ElProgress | transitionDuration | `Duration` | 完成量变化的过渡时长。 |
| ElProgress | indeterminateDuration | `Duration` | 不确定进度动画的周期。 |

合并移动端 value/max/buffer/status/读数插槽与桌面 percentage/色标/圆环配置，percentage 与 value 互斥。ElProgressShape 将源私有形态改为品牌可读的只读配置。快照只存数据，不进行比例归一化、绘制或动画。移动端参照 lib/src/ui/mobile/components/progress/index.dart。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。

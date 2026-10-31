# Statistic

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/statistic` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElStatistic | `statisticBuilder` |

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElStatistic | value | `Object?` | 统计内容，数值以外的输入可作为文字展示。 |
| ElStatistic | title | `Object?` | 统计标题。 |
| ElStatistic | precision | `int` | 显示的小数位数。 |
| ElStatistic | groupSeparator | `String` | 数值分组分隔符，空串表示不分组。 |
| ElStatistic | formatter | `String Function(Object? value)?` | 自定义值格式化函数，优先于默认数值格式。 |
| ElStatistic | prefix | `Object?` | 读数前置内容。 |
| ElStatistic | suffix | `Object?` | 读数后置内容。 |
| ElStatistic | style | `ElStyle?` | 组件根样式。 |
| ElStatistic | titleStyle | `ElStyle?` | 统计标题样式。 |
| ElStatistic | valueStyle | `ElStyle?` | 统计读数样式。 |
| ElStatistic | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

仅声明值与格式回调，不执行小数位处理、千分位分组或渲染。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。

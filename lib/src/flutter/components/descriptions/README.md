# Descriptions

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/descriptions` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElDescriptionsItem | 只保存配置的数据类 |
| ElDescriptions | `descriptionsBuilder` |

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElDescriptionsItem | label | `Object?` | 条目标签内容。 |
| ElDescriptionsItem | child | `Object?` | 条目正文内容。 |
| ElDescriptionsItem | span | `int` | 条目占据的列数。 |
| ElDescriptionsItem | labelStyle | `ElStyle?` | 单项标签样式。 |
| ElDescriptionsItem | contentStyle | `ElStyle?` | 单项正文样式。 |
| ElDescriptions | items | `List<ElDescriptionsItem>` | 描述条目列表。 |
| ElDescriptions | title | `Object?` | 列表标题。 |
| ElDescriptions | extra | `Object?` | 标题旁的附加操作内容。 |
| ElDescriptions | column | `int` | 每行的列数。 |
| ElDescriptions | border | `bool` | 显示单元格边框。 |
| ElDescriptions | direction | `Axis` | 标签与内容的排列方向。 |
| ElDescriptions | style | `ElStyle?` | 组件根样式。 |
| ElDescriptions | titleStyle | `ElStyle?` | 列表标题样式。 |
| ElDescriptions | labelStyle | `ElStyle?` | 条目标签的默认样式。 |
| ElDescriptions | contentStyle | `ElStyle?` | 条目正文的默认样式。 |
| ElDescriptions | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

ElDescriptionsItem 是数据配置，不单独登记 Builder；不包含源 ElLevelType 品牌尺寸参数，也不执行跨列装箱。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。

# Segmented

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/form/segmented` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElSegmentedOption | 只保存配置的数据类 |
| ElSegmented | `segmentedBuilder` |

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElSegmentedOption | value | `Object?` | 选项业务值。 |
| ElSegmentedOption | label | `Object?` | 选项显示内容，省略时由实现使用值的文字。 |
| ElSegmentedOption | disabled | `bool` | 禁止选择该项。 |
| ElSegmented | value | `Object?` | 普通值输入，具体同步由品牌实现处理。 |
| ElSegmented | modelValue | `ValueNotifier<Object?>?` | 外部双向模型，生命周期由调用方管理。 |
| ElSegmented | onChanged | `ValueChanged<Object?>?` | 模型变化通知。 |
| ElSegmented | options | `List<ElSegmentedOption>` | 分段选项列表。 |
| ElSegmented | disabled | `bool` | 禁止整个分段控制器交互。 |
| ElSegmented | block | `bool` | 占满可用空间并均分选项。 |
| ElSegmented | direction | `Axis` | 选项排列方向。 |
| ElSegmented | style | `ElStyle?` | 组件根样式。 |
| ElSegmented | itemStyle | `ElStyle?` | 单个选项的样式。 |
| ElSegmented | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

ElSegmentedOption 是数据配置，不单独登记 Builder；不包含源 ElLevelType 品牌尺寸参数，不选择选项或驱动动画。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。

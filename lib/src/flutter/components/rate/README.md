# Rate

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/form/rate` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElRate | `rateBuilder` |

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElRate | value | `double?` | 普通值输入，具体同步由品牌实现处理。 |
| ElRate | modelValue | `ValueNotifier<double>?` | 外部双向模型，生命周期由调用方管理。 |
| ElRate | onChanged | `ValueChanged<double>?` | 模型变化通知。 |
| ElRate | max | `int` | 评分图标的总数。 |
| ElRate | allowHalf | `bool` | 允许选择半分。 |
| ElRate | clearable | `bool` | 再次激活当前分值时允许清零。 |
| ElRate | disabled | `bool` | 禁止修改评分。 |
| ElRate | iconSize | `double?` | 显式评分图标尺寸。 |
| ElRate | icon | `Object?` | 选中图标，null 时使用品牌默认图标。 |
| ElRate | voidIcon | `Object?` | 未选中图标，null 时使用品牌默认图标。 |
| ElRate | colors | `List<Color>?` | 按分值分段使用的颜色。 |
| ElRate | inactiveColor | `Color?` | 未选中图标的颜色。 |
| ElRate | showText | `bool` | 显示与当前分值对应的辅助文字。 |
| ElRate | showScore | `bool` | 显示分值读数。 |
| ElRate | texts | `List<String>?` | 按分值对应的辅助文字列表。 |
| ElRate | scoreTemplate | `String?` | 分值模板，其中 {value} 表示当前分值。 |
| ElRate | style | `ElStyle?` | 组件根样式。 |
| ElRate | textStyle | `ElStyle?` | 辅助文字或读数的样式。 |
| ElRate | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

默认图标为 null，品牌决定具体星形资源；声明不计算半分、不进行悬停预览或表单绑定。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。

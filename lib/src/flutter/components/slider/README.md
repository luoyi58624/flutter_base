# Slider

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/form/slider` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElSlider | `sliderBuilder` |

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElSlider | value | `double?` | 普通值输入，具体同步由品牌实现处理。 |
| ElSlider | modelValue | `ValueNotifier<double>?` | 外部双向模型，生命周期由调用方管理。 |
| ElSlider | onChanged | `ValueChanged<double>?` | 模型变化通知。 |
| ElSlider | min | `double` | 允许的最小值。 |
| ElSlider | max | `double` | 允许的最大值。 |
| ElSlider | onChangeStart | `ValueChanged<double>?` | 用户开始拖动时通知当前值。 |
| ElSlider | onChangeEnd | `ValueChanged<double>?` | 用户结束拖动时通知当前值。 |
| ElSlider | divisions | `int?` | 离散分段数量，null 表示连续选择。 |
| ElSlider | label | `String?` | 显示在滑块提示中的文字。 |
| ElSlider | activeColor | `Color?` | 已完成轨道颜色。 |
| ElSlider | inactiveColor | `Color?` | 未完成轨道颜色。 |
| ElSlider | secondaryActiveColor | `Color?` | 次级活动轨道颜色。 |
| ElSlider | thumbColor | `Color?` | 滑块颜色。 |
| ElSlider | overlayColor | `WidgetStateProperty<Color?>?` | 按交互状态解析的覆盖色。 |
| ElSlider | mouseCursor | `MouseCursor?` | 滑块鼠标光标。 |
| ElSlider | semanticFormatterCallback | `SemanticFormatterCallback?` | 将数值转为辅助技术读数。 |
| ElSlider | focusNode | `FocusNode?` | 调用方管理的外部焦点节点。 |
| ElSlider | allowedInteraction | `SliderInteraction?` | 允许的滑动与轨道点击方式。 |
| ElSlider | padding | `EdgeInsetsGeometry?` | 轨道周围的内边距。 |

复用 Flutter SliderInteraction 与 SemanticFormatterCallback；声明不创建 Material Slider，不钳制值或处理手势。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。

# Segmented

`ElSegmented<T>` 继承 `ElModelValue<T>`，保留完整业务值类型。参数为值通道、`List<ElSegmentedOption<T>>` options、disabled、style 和 semanticLabel；选项只声明 value / label / disabled。

接口以 Web 的单行分段选择为准，不保留 block、竖向方向或额外的单项布局协议。当前值通过 currentValue 交给品牌，接口不执行选择回退或键盘导航。两端暂用官方 SegmentedButton 承接，边界见 [Material 替代](../../../ui/material/README.md)。

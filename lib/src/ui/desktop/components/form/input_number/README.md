# InputNumber

从 Element Plus `components/form/input_number/index.dart` 迁入，注册到 `ElementPlusThemeData.inputNumber`。通用参数见 [InputNumber](../../../../../flutter/components/input_number/README.md)，安装见 [Desktop](../../../README.md)。

保留 num? 绑定、空值、步长、严格步长、上下限、精度、左右或右侧控件及键盘操作。内层输入沿通用 ElInput 和桌面品牌输入实现工作，复合组件保留自己的表单值通道，避免内层文本反写数值字段。

# Input

从 Element Plus `components/form/input/` 迁入，注册到 `ElementPlusThemeData.input`。通用参数见 [Input](../../../../../flutter/components/input/README.md)，安装见 [Desktop](../../../README.md)。

保留唯一 ElEditableController 的编辑、IME、光标与选区通道，以及 value / modelValue / 表单绑定、文本回灌和通知时序。ElInputController 挂载与卸载仍由源控制桥负责。

shell.dart、slots.dart 保留输入外壳、占位、前后缀、清空和密码动作布局；metrics.dart 是输入族共用度量。保留多行、字数、禁用、只读、自动填充和平台输入回调，没有以 Flutter TextField 替换。

# Button

从 Element Plus `components/basic/button/index.dart` 迁入，注册到 `ElementPlusThemeData.button`。通用参数见 [Button](../../../../../flutter/components/button/README.md)，安装见 [Desktop](../../../README.md)。

保留 link、text、ghost、plain、实心按钮的外观优先级，五档尺寸、左右内容槽、图标按钮、胶囊和正圆几何。disabled 与 loading 分开处理；loading 替换左侧内容并阻止默认激活，保留原尺寸与加载配色。

公共 ElButton 维护模型，品牌实现组合 ElButtonView，并保留 Space 按压控制器、键盘焦点环、选中状态和事件取消规则。调用方的 style 在默认外观之后合并，正圆按钮在合并后保持等宽高。

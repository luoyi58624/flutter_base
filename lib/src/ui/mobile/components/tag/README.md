# Tag

`MyTag` 保留展示 / 受控选择、tone 和 change 后 click 的原有行为。`myTagBuilder` 是纯外观实现，直接读取 ElTag.selected 与 isToggle；通用模型切换由外层 ElTag 完成。

通用接口支持 type、light / dark / plain、round / hit、style、关闭入口与 closeStyle / closeSemanticLabel。关闭入口使用独立按钮并停止事件冒泡，关闭不会同时切换主标签；主入口的 event、focusNode、semanticLabel 由公共宿主持有。

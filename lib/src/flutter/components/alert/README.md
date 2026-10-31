# Alert

提示组件的参数声明；title、description 接受文本或 Widget，type / effect 描述语义与填充方式，closable / closeText / onClose 描述关闭入口，style、titleStyle、descriptionStyle、closeStyle 提供分层样式。

`alertBuilder(context, component)` 接收原始 ElAlert。当前不实现关闭、显示状态或布局；父级负责根据关闭请求移除组件，品牌 Builder 后续提供外观与交互。默认 Builder 为 null。

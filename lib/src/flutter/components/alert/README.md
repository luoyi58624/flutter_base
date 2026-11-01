# Alert

ElAlert 对应 Web Notice，不再额外声明 ElNotice。继承 `ElModelValue<bool>`，value / modelValue / onChanged 沿用公共模型，默认显示 true；外部模型可以在关闭后重新展开。

共同参数为 type、title、description（对应 Web message）、closable、icon、style、semanticLabel、onClose。默认 type 为 info，closable 为 false；icon 默认占位符表示按状态选择图标，显式 null 隐藏，自定义内容替换默认图标。

品牌响应关闭时须先写入 currentValue=false，再调用 onClose，因此模型变化通知先于用户关闭通知。外部模型变为 false 不应另发 onClose；关闭交互、焦点迁移和退场动画由品牌实现，公共声明不执行关闭算法。

移除 effect、center、closeText、独立文字/关闭样式等 Element Plus 形态。当前移动端尚未登记 Alert Builder。

# Switch

`MySwitch` 保留 47×28 轨道、22 像素滑块、原值通知方式和 Space 激活。`mySwitchBuilder` 使用通用 ElFormModelValue<bool> 绑定 ElSwitch，并以相同移动端皮肤提供完整配置。

通用开关支持 value / modelValue / onChanged、祖先 Form 字段、activeColor / inactiveColor、轨道内容与滑块内容、loading / disabled、height / gap / widthAspect / slide、style / trackStyle、event / focusNode / semanticLabel。省略值且不绑定表单时默认为 false。

通用模型沿用 ElModelValue / ElFormModelValue 的通知规则：用户切换、外部 notifier 或表单字段变化会通知 onChanged，value 参数回灌不通知；原 MySwitch 仍只在用户操作时通知。loading 保留焦点并禁止操作；减少动态效果或 slide=false 时滑块直接到位。

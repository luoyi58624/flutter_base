# Switch

用户通过 ElSwitch 调用移动端开关。内部 `switcher` 使用通用 ElFormModelValue<bool> 绑定模型，并保留 47×28 默认轨道和 22 像素滑块；默认不创建焦点，显式配置 focusNode 或焦点变体后支持 Space 激活。具体组件不从移动端入口导出。

通用开关支持 value / modelValue / onChanged、祖先 Form 字段、activeColor / inactiveColor、轨道内容与滑块内容、loading / disabled、height / gap / widthAspect / slide、style / trackStyle、event / focusNode / semanticLabel。省略值且不绑定表单时默认为 false。

通用模型沿用 ElModelValue / ElFormModelValue 的通知规则：用户切换、外部 notifier 或表单字段变化会通知 onChanged，value 参数回灌不通知。loading 保留焦点并禁止操作；减少动态效果或 slide=false 时滑块直接到位。

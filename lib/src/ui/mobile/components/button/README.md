# Button

`MyButton` 保留 my-ui 的七种 variant、图标名、表单动作与点击事件。`myButtonBuilder` 同时支持通用 ElButton，使用公共声明的 onPressed、selected、isToggle，不创建第二份切换模型。

通用按钮支持 type / bgColor、plain / text / bg / link / ghost、round / circle / block、loading / disabled、左右内容槽，以及样式、事件、焦点和辅助名称。变体优先级为 link、text、ghost、plain。child 为 IconData 时按图标按钮处理。

`event.onTap` 先于默认动作，可通过 preventDefault 取消；loading 保留内容尺寸与焦点，禁止激活。原 MyButton 的 submit / reset 仅在品牌 API 中保留，通用按钮不隐式触发表单提交。

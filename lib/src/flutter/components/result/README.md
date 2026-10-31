# Result

结果展示的参数声明，保留 title、subTitle、icon、status、child 和分层样式。icon 支持图标或 Widget；child 用于底部操作内容。

`resultBuilder(context, component)` 接收原始 ElResult。当前不选择默认图标、不排版、不处理按钮操作；由后续品牌实现承担，默认 Builder 为 null。

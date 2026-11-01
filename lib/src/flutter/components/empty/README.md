# Empty

ElEmpty 对应 Web Empty，state 使用 ElEmptyState.empty / error，额外参数只有 title、description、icon、child、style、semanticLabel。

省略 title / icon 时由品牌根据状态选择：空内容标题“这里还没有内容”，错误标题“暂时无法加载”；child 用于重试等操作或补充内容。接口不构造默认图形或业务动作。

不保留插画 image、imageSize 或分层文字样式参数，避免与 Web 状态职责分叉。当前移动端尚未登记 Empty Builder。

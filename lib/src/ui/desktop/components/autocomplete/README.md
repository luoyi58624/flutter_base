# Autocomplete

从 Element Plus `components/form/autocomplete/` 迁入，由桌面预设注册。通用参数见 [Autocomplete](../../../../flutter/components/autocomplete/README.md)，安装见 [Desktop](../../README.md)。

保留同步或异步数据源、查询防抖、过期请求丢弃、输入法组合期控制、键盘选择、加载与错误内容。输入文本仍是 String，候选业务数据使用独立的泛型 T。

候选层外观保留在 panel.dart，由 ElPopup 锚定在输入框下方，开闭由输入框的键盘与 IME 状态决定，进退场共用 dropdown_transition.dart。

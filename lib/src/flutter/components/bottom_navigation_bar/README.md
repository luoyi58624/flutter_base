# BottomNavigationBar

`ElBottomNavigationBar` 声明下标模型、items、整组禁用和样式，通过 `bottomNavigationBarBuilder(context, component)` 分派。`ElBottomNavigationBarItem` 保存 label、icon、selectedIcon 和 disabled。

本目录不建立选择模型、等宽布局、安全区或键盘操作。value 的普通初值保留为 0，外部 notifier 的订阅与优先级交由后续实现。

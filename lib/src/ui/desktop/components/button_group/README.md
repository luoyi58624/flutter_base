# ButtonGroup

从 Element Plus `components/basic/button_group/` 迁入，由桌面预设注册。通用参数见 [ButtonGroup](../../../../flutter/components/button_group/README.md)，安装见 [Desktop](../../README.md)。

保留普通、single、multi 模式、List / Set 集合类型、mandatory 选择规则、表单绑定、禁用与条目回调。普通组不挂选择模型；可取消的单选模型需要使用可空泛型。

index.dart 处理条目行为和品牌外观，render.dart 保留源相邻按钮连接边框、像素接缝和层序布局实现。未替换为独立按钮简单拼接。

# 通用主题规范

`ElTokens` 只声明变量键，`context.elTheme` 提供一一对应的同名类型化读取，例如 `ElTokens.$cardPressColor` 对应 `context.elTheme.cardPressColor`。从 `package:flutter_base/flutter.dart` 导出，其他公共入口复用同一份声明。

这里不保存颜色、字体、阴影和度量的默认值，也不在 getter 中混色或借用其他 token。所有默认值由 mobile、desktop 各自的 tokens.dart 定义，通过已有 ElView 变量表注入。边框色阶、禁用色与选区颜色也是独立 token，可以单独覆写。

读取只登记对应键的依赖，`context.elTheme` 入口本身不订阅；变量缺失或类型不符会抛出 StateError。普通 ElView 可以直接注入业务需要的 token，不要求安装品牌主题；读取未提供的 token 不会自动回退到某个品牌。`elVarOr` / `elVarOrElse` 仍允许调用方明确提供兜底。

新增主题字段时同步更新 ElTokens、ElThemeExt 和两端默认表。暗色表保持增量，避免覆盖调用方在基础层设置的字体或度量。

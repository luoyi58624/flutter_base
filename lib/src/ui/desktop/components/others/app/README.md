# Desktop Theme

`ElDesktopTheme` 安装桌面组件实现，并将通用默认变量注入 ElView。两端共享 `ElTheme` 键和 `context.elTheme` 读取入口，局部覆盖直接使用普通 ElView。公共用法见 [Desktop](../../../README.md)。

| 参数或接口 | 用途 |
| --- | --- |
| compact | 桌面紧凑密度，默认 false，可用 ElDesktopTheme.$compact 局部覆写 |
| themeMode / breakpoint / locale | 明暗及过渡、断点与语言环境 |
| style | 默认表之后合并的实际样式与 vars / onDark.vars |
| componentBuilders | 在品牌实现预设上合并的实现 |
| ElementPlusThemeData | 12 个组件及 FormItem、TableStyle 的默认 Builder |
| lightVars / darkVars | 默认浅色表与暗色增量 |

theme.dart 保留源组件登记方式；tokens.dart 与 shadow.dart 提供默认变量和阴影。外层 ElView 注入变量，内层 Builder 读取后生成实际根样式。Text Builder 原样透传 Flutter Text 的参数；FormItem Builder 只为通用 ElFormItemView 提供标签与错误颜色。

桌面组件固定采用 hover、焦点和按压反馈，不再根据运行平台切换成移动端外观。密度仅区分普通与紧凑两种，页面正文与独立菜单行高不随密度整体缩放。

安装器只提供主题、组件和候选层宿主。源 ElApp 的服务与平台 chrome 依赖没有对应通用接口，因此该应用根没有以 ElApp 名称迁入。

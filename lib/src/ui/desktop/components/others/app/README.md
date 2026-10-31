# Desktop Theme

`ElDesktopTheme` 提供桌面品牌安装，`ElThemeData` 和 `ElTheme` 保留源 Element Plus 的类型化主题与局部覆盖。公共用法见 [Desktop](../../../README.md)。

| 参数或接口 | 用途 |
| --- | --- |
| theme / darkTheme / size | 浅色、暗色主题与尺寸覆盖 |
| themeMode / breakpoint / locale | 明暗及过渡、断点与语言环境 |
| style | 根默认样式之后合并的样式 |
| componentBuilders | 在品牌实现预设上合并的实现 |
| ElementPlusThemeData | 12 个组件及 FormItem、TableStyle 的默认 Builder |
| ElTheme | 局部组件主题与尺寸，不重复安装 Overlay |

theme.dart 保留源主题登记方式；palette.dart 与 shadow.dart 保留源默认颜色、五档度量和阴影。Text Builder 原样透传 Flutter Text 的参数；FormItem Builder 只为通用 ElFormItemView 提供标签与错误颜色。

安装器只提供主题、组件和候选层宿主。源 ElApp 的服务与平台 chrome 依赖没有对应通用接口，因此该应用根没有以 ElApp 名称迁入。

# 官方主题桥

`material_theme.dart` 沿用旧 el 的 `ElMaterialThemeExt`，将通用主题变量转换为 Flutter Material 的 `ThemeData`，从 `package:flutter_base/flutter_base.dart` 导出，desktop.dart / mobile.dart 也可直接使用。

在 ElMobileTheme、ElDesktopTheme 或局部 ElView 的后代 context 读取：

```dart
Builder(
  builder: (context) => Theme(
    data: context.elMaterialThemeData,
    child: Scaffold(body: Text('官方组件')),
  ),
);
```

- `context.elMaterialThemeData` 跟随当前 ElView 明暗，读取目标级联值，由 Material 的主题动画负责插值，避免重复使用 ElView 的中间采样。
- `ElView.of(context).themeMode` 提供统一的主题动画配置，默认 200ms、线性过渡；将其 `duration!`、`curve!` 分别传给 `MaterialApp.themeAnimationDuration`、`themeAnimationCurve`，让 Material 与 ElView 使用相同的时序。自定义配置只需在祖先 ElView.themeMode 或 ElMobileTheme.themeMode 声明一次。
- `context.elMaterialTheme(Brightness.light / Brightness.dark)` 显式构建目标轴，重放已有 vars / onDark 与激活变体，可供 MaterialApp.theme / darkTheme 使用；两套组件的明暗控制源仍应保持一致。
- 没有主题变量时使用 Flutter 官方默认主题；存在主题变量时严格读取品牌注入值，不在通用层保存默认色表。
- 官方组件的配色、边框、圆角和字号层级沿用原实现，覆盖按钮、导航、卡片、列表、输入、菜单、弹窗、日期／时间选择器、进度及提示等主题。
- 字体读取最近 ElView 实际继承的字号、字重、字体族、回退、行高、字距、字形及显式字体特性／轴值；字号按原有层级同比调整，按钮和标题字重读取对应主题变量。
- 未配置字体族或回退时保持 Flutter 默认，不加载字体文件；ElMobileTheme 会将 android_system_font_weight 返回的系统字重轴注入 ElView，官方主题原样承接，插件返回 null 时保留默认，显式轴配置优先。

旧字段按当前公共变量对应：textColorXs/Sm/Md/Lg 分别使用 textColor/textRegular/textSecondary/textPlaceholder，borderWidths 的默认档使用 borderWidth，appbarColor 使用 cardColor。特定官方组件需要额外覆写时，可直接对结果调用官方 copyWith。

`material_theme_vars.dart` 复用现有样式解析器、级联通知及 Element 退订机制，处理显式反向明暗的变量和字体读取；不修改正常 getVar 的订阅口径。扩展不自动改变应用的 Theme，example 已在 MaterialApp 外安装 ElMobileTheme，并通过 `theme: context.elMaterialThemeData` 使用。

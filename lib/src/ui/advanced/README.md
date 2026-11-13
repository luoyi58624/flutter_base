# 进阶能力

## 高级组件

[`ElInfiniteScroll`](widgets/infinite_scroll/README.md) 提供下拉刷新、触底分页和自定义内容布局，经 `package:flutter_base/ui.dart` 和聚合入口导出。

## 官方主题桥

[`ElMaterialThemeExt`](utils/material/material_theme.dart) 沿用旧 el 的同名扩展，将通用主题变量转换为 Flutter Material 的 `ThemeData`，从 `package:flutter_base/flutter_base.dart` 导出，desktop.dart / mobile.dart 也可直接使用。

从安装组件预设的 `ElComponentProvider` 或局部 `ElView` 的后代读取。

```dart
Builder(
  builder: (context) => Theme(
    data: context.elMaterialThemeData,
    child: Scaffold(body: Text('官方组件')),
  ),
);
```

- `context.elMaterialThemeData` 跟随当前 ElView 明暗，读取目标级联值，由 Material 的主题动画负责插值，避免重复使用 ElView 的中间采样。
- `ElView.of(context).themeMode` 提供统一的主题动画配置，默认 200ms、线性过渡。应用可在祖先 `ElView.themeMode` 声明明暗和时序，再将读出的时长与曲线传给 `MaterialApp`。
- `context.elMaterialTheme(Brightness.light / Brightness.dark)` 显式构建目标轴，重放已有 vars / onDark 与激活变体，可供 MaterialApp.theme / darkTheme 使用；两套组件的明暗控制源仍应保持一致。
- 没有主题变量时使用 Flutter 官方默认主题；存在主题变量时严格读取品牌注入值，不在通用层保存默认色表。
- 官方组件的配色、边框、圆角和字号层级沿用原实现，覆盖按钮、导航、卡片、列表、输入、菜单、弹窗、日期／时间选择器、进度及提示等主题。
- 字体读取最近 ElView 实际继承的字号、字重、字体族、回退、行高、字距、字形及显式字体特性／轴值；字号按原有层级同比调整，按钮和标题字重读取对应主题变量。
- 原生字体与应用主题由应用设置。应用也可以用 `ElView.style` 显式配置 El 子树的字体或字重轴。

旧字段按当前公共变量对应：textColorXs/Sm/Md/Lg 分别使用 textColor/textRegular/textSecondary/textPlaceholder，borderWidths 的默认档使用 borderWidth，appbarColor 使用 cardColor。特定官方组件需要额外覆写时，可直接对结果调用官方 copyWith。

[`material_theme_vars.dart`](utils/material/material_theme_vars.dart) 复用现有样式解析器、级联通知及 Element 退订机制，处理显式反向明暗的变量和字体读取；不修改正常 getVar 的订阅口径。扩展不自动改变应用的 Theme，example 在 MaterialApp 外通过 ElComponentProvider 安装移动预设，并通过 `theme: context.elMaterialThemeData` 使用。

## 命令式路由

通过 `package:flutter_base/flutter_base.dart` 使用 `el.router` 和 `context.elRouter`。将 `el.navigatorKey` 传给应用的根导航器，使用 GoRouter 时传给 GoRouter 的 `navigatorKey`。

```dart
final result = await el.router.pushPage<String>(DetailsPage());
// 在详情页内返回结果。
context.elRouter.pop('saved');
```

`el.router` 操作根导航器，`context.elRouter` 操作最近的导航器。页面便捷方法默认使用应用的 Material 页面过渡。可替换 `ElRouterServiceExt.instance`，传入 `ElRouterService(pageTransitionsBuilder: builder)` 来设置自定义过渡。

## 应用绑定

[`ElWidgetsFlutterBinding`](sdk/binding/binding.dart) 通过 `package:flutter_base/flutter_base.dart` 导出。应用可在插件初始化和 `runApp` 之前调用 `ElWidgetsFlutterBinding.ensureInitialized()`，启用 Android 触摸重采样。

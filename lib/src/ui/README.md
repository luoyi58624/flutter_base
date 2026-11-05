# UI 品牌实现

`flutter/components` 声明通用组件接口，本目录安装各品牌的主题与 Builder。应用显式选择移动端或桌面入口；`flutter_base.dart` 保持通用入口，不自动选择品牌。

通用主题规范见 [flutter/commons/theme](../flutter/commons/theme/README.md)。ElTokens 与 context.elTheme 在 flutter 层统一声明，品牌目录只提供 token 的默认值、明暗增量及组件外观。

## 移动端

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

void main() {
  runApp(MaterialApp(
    home: ElComponentProvider(
      components: el.mobileComponents,
      child: ElButton(onPressed: () {}, child: '保存'),
    ),
  ));
}
```

`el.mobileComponents` 同时提供移动端组件实现和 token。Provider 可以包住应用，也可以放在任意需要该预设的子树。支持范围见 [Mobile](mobile/README.md)。

## 桌面端

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

void main() {
  runApp(MaterialApp(
    home: ElComponentProvider(
      components: el.desktopComponents,
      child: ElButton(onPressed: () {}, child: '保存'),
    ),
  ));
}
```

`el.desktopComponents` 同时提供 Element Plus 组件实现和 token。输入候选等弹层使用应用提供的 Overlay，原生主题、文字排版和导航也由应用管理。支持范围见 [Desktop](desktop/README.md)。

## 组合与覆盖

两端共享 `ElTokens` 键和 `context.elTheme` 读取扩展。局部只改 token 时可以使用普通 `ElView`。

```dart
ElView(
  style: ElStyle(
    vars: {ElTokens.$primary: Colors.blue},
    onDark: ElStyle(vars: {ElTokens.$primary: Colors.green}),
  ),
  child: Builder(builder: (context) => Text('主色', style: TextStyle(color: context.elTheme.primary))),
);
```

读取哪个变量就订阅哪个变量；仅访问 `context.elTheme` 不建立依赖。背景对比文字使用 `textOnLight`、`textOnDark`，无需反向读取另一套主题。组件专属变量由各组件声明键并提供本地默认值，不加入全局注入表。

明暗值由声明节点的 `onDark.vars` 应用。后代只改变 themeMode 不会重选祖先变量的另一套配色；需要局部配色时声明自己的变量变体，或安装新的主题宿主。

完整品牌预设替换组件表和 token，缺失的实现仍为空。局部传入 `ElComponents(button: customButton)` 时，只覆写当前子树的按钮，其余实现继续继承。通用声明和 Builder 契约见 [Components](../flutter/components/README.md)。

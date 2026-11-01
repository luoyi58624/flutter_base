# UI 品牌实现

`flutter/components` 声明通用组件接口，本目录安装各品牌的主题与 Builder。应用显式选择移动端或桌面入口；`flutter_base.dart` 保持通用入口，不自动选择品牌。

## 移动端

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

void main() {
  runApp(MaterialApp(
    home: ElMobileTheme(
      child: ElButton(onPressed: () {}, child: '保存'),
    ),
  ));
}
```

移动端由 ElMobileTheme 向 ElView 注入默认主题变量并安装组件实现，业务代码使用通用 El* 声明。具体组件、Builder 和辅助函数留在 src 内部，不从移动端入口导出；独立的 ElBottomTabbar 继续公开。支持范围见 [Mobile](mobile/README.md)。

## 桌面端

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

void main() {
  runApp(MaterialApp(
    home: ElDesktopTheme(
      child: ElButton(onPressed: () {}, child: '保存'),
    ),
  ));
}
```

桌面端从 Element Plus 迁入可满足通用接口的品牌实现，采用普通／紧凑两种控件密度，保留明暗默认变量和源组件行为。ElDesktopTheme 安装主题、组件 Builder 与候选面板所需的 Overlay 环境；服务类组件和平台菜单等待各自接口，当前不注册。支持清单及缺口见 [Desktop](desktop/README.md)。

## 组合与覆盖

两端共享 `ElTheme` 的通用颜色、阴影、字体和基础度量键，以及同一个 `context.elTheme` 读取扩展。桌面密度由 `ElDesktopTheme(compact: ...)` 和桌面专用的布尔变量控制，移动端保持自己的固定尺寸。通过普通 ElView 局部覆盖，无需复制主题对象：

```dart
ElView(
  style: ElStyle(
    vars: {ElTheme.$primary: Colors.blue},
    onDark: ElStyle(vars: {ElTheme.$primary: Colors.green}),
  ),
  child: Builder(builder: (context) => Text('主色', style: TextStyle(color: context.elTheme.primary))),
);
```

读取哪个变量就订阅哪个变量；仅访问 `context.elTheme` 不建立依赖。背景对比文字使用 `textOnLight`、`textOnDark`，无需反向读取另一套主题。组件专属变量由各组件声明键并提供本地默认值，不加入全局注入表。

明暗值由声明节点的 `onDark.vars` 应用。后代只改变 themeMode 不会重选祖先变量的另一套配色；需要局部配色时声明自己的变量变体，或安装新的主题宿主。

两个入口都重新导出通用 flutter_base API；同时导入两端时使用库前缀区分品牌主题。不同主题可嵌套，后代从最近的 ElComponentProvider 读取该品牌的完整组件配置。需要替换某项实现时，在品牌安装器的 componentBuilders 参数中显式传入覆盖配置。

暂未迁入的组件保持未登记状态，不借用祖先品牌实现填补缺口。通用声明和 Builder 契约见 [Components](../flutter/components/README.md)。

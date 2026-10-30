# UI 品牌实现

`flutter/components` 声明通用组件接口，本目录安装各品牌的主题与 Builder。应用显式选择移动端或桌面入口；`flutter_base.dart` 保持通用入口，不自动选择品牌。

## 移动端

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

void main() {
  runApp(MaterialApp(
    home: MyTheme(
      child: ElButton(onPressed: () {}, child: '保存'),
    ),
  ));
}
```

移动端沿用 my-ui 的 MyTheme / MyThemeData 与既有 My* 组件。已有通用实现通过 MyTheme 安装，业务代码可以使用同一套 El* 声明。品牌组件与通用接口之间的支持范围见 [Mobile](mobile/README.md)。

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

桌面端从 Element Plus 迁入可满足通用接口的品牌实现，保留类型化 ElThemeData、尺寸档、明暗色板和源组件行为。ElDesktopTheme 安装主题、组件 Builder 与候选面板所需的 Overlay 环境；服务类组件和平台菜单等待各自接口，当前不注册。支持清单及缺口见 [Desktop](desktop/README.md)。

## 组合与覆盖

两个入口都重新导出通用 flutter_base API；同时导入两端时使用库前缀区分品牌主题。不同主题可嵌套，后代从最近的 ElComponentProvider 读取该品牌的完整组件配置。需要替换某项实现时，在品牌安装器的 componentBuilders 参数中显式传入覆盖配置。

暂未迁入的组件保持未登记状态，不借用祖先品牌实现填补缺口。通用声明和 Builder 契约见 [Components](../flutter/components/README.md)。

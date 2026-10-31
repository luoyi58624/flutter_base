# ListTile

## 公共声明

`ElListTile` 提供普通、page、switcher 三个构造，声明标题、副标题、前后槽、目标页面或开关值通道，通过 `listTileBuilder(context, component)` 分派。开关通道沿用原列表行的 dynamic 模型，开关模式的变化值为 bool。`ElListTileGroup` 声明标题、行集合和容器样式，通过 `listTileGroupBuilder` 分派。

新声明不包含品牌尺寸档位，不实现布局、导航、模型绑定或分隔线。以下已有 My* 具体入口保持原样。

## 既有入口

当前目录提供 `MyListTile` 和 `MyListGroup`，分别位于 [index.dart](index.dart) 和 [group.dart](group.dart)。二者直接组合 ElView，不依赖组件品牌 Builder；导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

```dart
MyListGroup(
  title: Text('设置'),
  children: [
    MyListTile(
      title: '通知',
      icon: Icon(Icons.notifications_outlined),
      onPressed: () { debugPrint('打开通知设置'); },
    ),
    MyListTile(title: '关于', icon: Icon(Icons.info_outline)),
  ],
);
```

| 接口 | 用途 |
| --- | --- |
| MyListTile.title / icon / onPressed | 字符串标题、可选图标与点击回调 |
| MyListTile.iconWidth | 当前图标区域宽度，默认 56 逻辑像素 |
| MyListGroup.children | 必填的列表项集合 |
| MyListGroup.title | 保留的分组标题参数，当前实现尚未绘制 |

MyListGroup 提供白色圆角容器和子项索引环境；MyListTile 根据索引决定是否绘制分隔线，并提供固定的悬停、按压反馈。列表项应放在 MyListGroup 或其他 ElChildIndex 环境中。当前接口的名称和固定样式保持源码现状。

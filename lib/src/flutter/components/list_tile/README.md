# ListTile

## 公共声明

`ElListTile` 提供普通和 `switcher` 两个构造，通过 `listTileBuilder(context, component)` 分派。没有 `page` 构造或路由参数，导航由调用方在 `onTap` 中处理。

| 范围 | 参数 |
| --- | --- |
| 列表行共用 | title / subtitle / leading / disabled / style / event / focusNode / semanticLabel |
| 普通行 | valueText / trailing / onTap |
| 开关行 | bool? value / ValueNotifier<bool>? modelValue / ValueChanged<bool>? onChanged / loading / switchStyle |
| 列表组 | title / description / List<Widget> children / style / semanticLabel |

普通行的 `valueText` 是右侧当前值，与后缀独立。`trailing` 默认为现有的 `ElEmptyWidget.instance` 占位符，品牌实现通过 `identical` 识别并绘制默认箭头；显式传 `null` 完全移除后缀与对应间距，其他值替换默认箭头。移动实现应复用 `ElFlutterUtil.hasAncestorWidget`，根据 `MaterialApp` / `CupertinoApp` 选择右箭头，不根据设备平台选择。

开关行不接受 `trailing` 或 `valueText`，末端固定为开关；`value` 与 `modelValue` 互斥，均未提供时使用 false。整行与内部开关共享一次激活，避免一次点击切换两次。触摸反馈延迟通过 `event.config` 配置，不重复提供行参数。

`ElListTileGroup` 通过 `listTileGroupBuilder(context, component)` 分派，只声明标题、说明、内容和样式，不接管单选或多选，也不引入 options 数据协议。

当前仅整理接口，不实现布局、箭头、模型绑定或分隔线，也不安装 mobile Builder。以下已有 My* 具体入口保持原样。

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

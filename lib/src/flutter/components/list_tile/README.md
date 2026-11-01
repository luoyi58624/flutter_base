# ListTile

## 公共声明

`ElListTile<T>` 继承 `ElModelValue<T>`，提供普通、`switcher`、`popup` 三个构造，通过泛型 `listTileBuilder<T>(context, component)` 分派。没有 `page` 构造或路由参数，导航由调用方在 `onTap` 中处理。

| 范围 | 参数 |
| --- | --- |
| 列表行共用 | value / modelValue / onChanged / title / subtitle / leading / disabled / style / event / focusNode / semanticLabel |
| 普通行 | valueText / trailing / onTap |
| 开关行 | 使用 bool 泛型 / loading / switchStyle |
| 弹窗单选行 | options / valueText / trailing / popupAnchor / popupMaxHeight / popupStyle / optionStyle / closeOnSelect / popupLabel |
| 列表组 | title / description / List<Widget> children / style / semanticLabel |

`value`、`modelValue`、`onChanged` 直接沿用基类的 `T?`、`ValueNotifier<T>?`、`ValueChanged<T>?`，不另外声明一份值通道。`value` 与 `modelValue` 互斥，外部模型更新和普通值回灌沿用 ElModelValue 的通知规则。显式非空 T 必须提供初始值或模型；允许未选择时使用 `ElListTile<String?>`，普通无绑定行可省略泛型。品牌构建和事件通过挂载后的 `currentValue` 读写同一模型，不另建绑定。

普通行的 `valueText` 是右侧当前值，与后缀独立。`trailing` 默认为现有的 `ElEmptyWidget.instance` 占位符，品牌实现通过 `identical` 识别并绘制默认图标；显式传 `null` 完全移除后缀与对应间距，其他值替换默认图标。普通行的移动实现应复用 `ElFlutterUtil.hasAncestorWidget`，根据 `MaterialApp` / `CupertinoApp` 选择右箭头，不根据设备平台选择。

开关行使用 `ElListTile<bool>.switcher`，不接受 `trailing` 或 `valueText`，末端固定为开关，未提供值通道时从 false 开始。整行与内部开关共享一次激活，避免一次点击切换两次。触摸反馈延迟通过 `event.config` 配置，不重复提供行参数。

弹窗行承接 Web 列表页 `Popover + ListRow` 的单选组合：`options` 复用 `ElLabelModel<T>`，每项 value 必须符合 T，选择后通过同一个 T 模型回写；`valueText` 省略时显示当前选中项的文案，默认后缀提示可打开菜单。`popupAnchor` 复用 `ElOverlayAnchor`，声明方位、间距、宽度匹配及边界避让，默认在行下方起边展开、间距 4；`closeOnSelect` 默认 true。不引入菜单多选或另一套选项模型。

```dart
ElListTile<bool>.switcher(title: '通知', modelValue: notifications);
ElListTile<String>.popup(
  title: '排序方式',
  modelValue: sort,
  options: [ElLabelModel('最新', 'latest'), ElLabelModel('最早', 'earliest')],
);
```

`ElListTileGroup` 通过 `listTileGroupBuilder(context, component)` 分派，只声明标题、说明、内容和样式，不接管单选或多选，也不引入 options 数据协议。

当前接通基类模型绑定和泛型 Builder 声明，不实现品牌布局、箭头、菜单弹出或分隔线，也不安装 mobile Builder。以下已有 My* 具体入口保持原样。

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

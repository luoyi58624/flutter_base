# ListTile

## 公共声明

`ElListTile<T>` 继承 `ElModelValue<T>`，提供普通、`switcher`、`popup` 三个构造，通过泛型 `listTileBuilder<T>(context, component)` 分派。没有 `page` 构造或路由参数，导航由调用方在 `onTap` 中处理。

| 范围 | 参数 |
| --- | --- |
| 列表行共用 | value / modelValue / onChanged / title / subtitle / leading / disabled / style / event / focusNode / semanticLabel |
| 普通行 | trailingText / trailing / onTap |
| 开关行 | 使用 bool 泛型 / loading / switchStyle |
| 弹窗单选行 | options / trailingText / trailing / popupAnchor / popupMaxHeight / popupStyle / optionStyle / closeOnSelect / popupLabel |
| 列表组共用 | title / List<ElListTile> children / bool leading |
| 单选、多选列表组 | 继承的 value / modelValue / onChanged |

`value`、`modelValue`、`onChanged` 直接沿用基类的 `T?`、`ValueNotifier<T>?`、`ValueChanged<T>?`，不另外声明一份值通道。`value` 与 `modelValue` 互斥，外部模型更新和普通值回灌沿用 ElModelValue 的通知规则。显式非空 T 必须提供初始值或模型；允许未选择时使用 `ElListTile<String?>`，普通无绑定行可省略泛型。品牌构建和事件通过挂载后的 `currentValue` 读写同一模型，不另建绑定。

普通行的 `trailingText` 是右侧当前值，与后缀独立。`trailing` 默认为现有的 `ElEmptyWidget.instance` 占位符，品牌实现通过 `identical` 识别并绘制默认图标；显式传 `null` 完全移除后缀与对应间距，其他值替换默认图标。普通行的移动实现应复用 `ElFlutterUtil.hasAncestorWidget`，根据 `MaterialApp` / `CupertinoApp` 选择右箭头，不根据设备平台选择。

开关行使用 `ElListTile<bool>.switcher`，不接受 `trailing` 或 `trailingText`，末端固定为开关，未提供值通道时从 false 开始。整行与内部开关共享一次激活，避免一次点击切换两次。触摸反馈延迟通过 `event.config` 配置，不重复提供行参数。

弹窗行承接 Web 列表页 `Popover + ListRow` 的单选组合：`options` 复用 `ElLabelModel<T>`，每项 value 必须符合 T，选择后通过同一个 T 模型回写；`trailingText` 省略时显示当前选中项的文案，默认后缀提示可打开菜单。`popupAnchor` 复用 `ElOverlayAnchor`，声明方位、间距、宽度匹配及边界避让，默认在行下方起边展开、间距 4；`closeOnSelect` 默认 true。不引入菜单多选或另一套选项模型。

```dart
ElListTile<bool>.switcher(title: '通知', modelValue: notifications);
ElListTile<String>.popup(
  title: '排序方式',
  modelValue: sort,
  options: [ElLabelModel('最新', 'latest'), ElLabelModel('最早', 'earliest')],
);
```

`ElListTileGroup<D>` 同样继承 `ElModelValue<D>`，通过泛型 `listTileGroupBuilder<D>(context, component)` 分派。D 表示完整模型类型，与按钮组一致：单选使用业务值类型（未选择时使用可空类型），多选使用 `List<业务值类型>`。业务值可用枚举、数字、字符串或自定义值对象，不限定为 String。

三个构造统一接受 `List<ElListTile> children`，子项的 `value` 就是选择值，标题、样式、禁用及前后缀直接由子项声明。模式复用现有 `ElModelValueType`，普通组为 null。分组只额外提供标题和 `leading` 布尔值：true 将单选／多选标记放在前面，false 放在后面。品牌通过 `currentValue` 读写同一模型。

```dart
final selection = ValueNotifier<ThemeMode?>(ThemeMode.system);
ElListTileGroup<ThemeMode?>.single(
  modelValue: selection,
  children: [
    ElListTile(value: ThemeMode.system, title: '跟随系统'),
    ElListTile(value: ThemeMode.dark, title: '暗色'),
  ],
);

final selections = ValueNotifier<List<ThemeMode>>([]);
ElListTileGroup<List<ThemeMode>>.multi(
  modelValue: selections,
  leading: false,
  children: [
    ElListTile(value: ThemeMode.light, title: '浅色'),
    ElListTile(value: ThemeMode.dark, title: '暗色'),
  ],
);
```

选择组默认生成单选／多选标记，不生成导航右箭头；具体子项继续使用已有内容、事件和样式入口。单选再次点击同项保持选中，多选以新 List 更新选中值。不另造 Item、模式枚举、options 或行 Builder。

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

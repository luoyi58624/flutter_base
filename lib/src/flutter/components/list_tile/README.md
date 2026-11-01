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

普通行的 `trailingText` 是右侧当前值，与后缀独立。`trailing` 默认为现有的 `ElEmptyWidget.instance` 占位符，品牌实现通过 `identical` 识别并绘制默认图标；显式传 `null` 完全移除后缀与对应间距，其他值替换默认图标。移动实现复用 `ElFlutterUtil.getAncestorElement`，根据最近的 `MaterialApp` / `CupertinoApp` 选择右箭头，不根据设备平台选择。

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

## 移动端实现

`MyTheme` 已安装两个列表 Builder，导入 `package:flutter_base/mobile.dart` 即可使用。实现位于 [mobile/list_tile](../../../ui/mobile/components/list_tile/README.md)，原有两类简版入口已移除。

布局沿用原代码：ElView 包 Row，内容区 Expanded；上下内边距 16，无前侧内容时留 16，有前侧内容时占 56。分组为圆角 16 的裁剪容器，通过 ElChildIndex 告知末项；分隔线用 Stack / Positioned 覆盖绘制，厚度 .5，左侧与正文对齐、右侧缩进 16。独立列表行不要求索引祖先。

颜色读取 `context.elTheme`，默认只提供按压反馈。单选使用 Flutter RadioGroup，开关尾部只绘制视觉，不另外绑定表单或外部模型；弹窗使用已有 ElPortal 管理定位、外点、Escape 和焦点恢复。

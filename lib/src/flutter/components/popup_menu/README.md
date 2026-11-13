# ElPopupMenu

包裹任意目标并在周围展开菜单。同一个组件覆盖三种形态：点击或悬停展开的下拉菜单、`cover` 覆盖目标展开的溢出菜单、`trigger: {.contextMenu}` 在右键或长按位置展开的右键菜单。条目复用 `ElContextMenuItem`，支持图标、勾选、快捷键文本、禁用、分隔线与多级子菜单。

## 构造

| 参数 | 类型与默认值 | 用途 |
| --- | --- | --- |
| `child` | `Widget`，必填 | 触发目标 |
| `items` | `List<ElContextMenuItem>`，必填 | 菜单条目 |
| `trigger` | `Set<ElPopupTrigger> = {click}` | 可组合 click、hover、focus、contextMenu |
| `placement` | `ElPlacement = .bottomStart` | 首选方位；右键菜单以指针位置为目标 |
| `cover` | `bool = false` | 覆盖目标，从目标所在位置展开 |
| `hoverIntent` | `ElHoverIntent` | 悬停触发的打开、关闭延迟 |
| `disabled` | `bool = false` | 禁用全部触发，已打开时关闭 |
| `controller` | `ElPopupController?` | 外部开闭 |
| `onOpenChanged` | `ValueChanged<bool>?` | 开闭状态变化 |
| `style` | `ElStyle?` | 在品牌菜单面板样式后合并 |
| `event` | `ElEvent?` | 目标事件，`preventDefault()` 阻止打开或关闭 |

两端共用 `ElComponents.popupMenu`。

## 调用

```dart
ElPopupMenu(
  cover: true,
  placement: .bottomEnd,
  items: [
    ElContextMenuItem(label: '刷新', onSelect: refresh),
    ElContextMenuItem(label: '导出为', children: [ElContextMenuItem(label: 'PDF', onSelect: exportPdf)]),
    ElContextMenuItem.divider(),
    ElContextMenuItem(label: '删除', enabled: false),
  ],
  child: ElButton(variant: .text, child: Icons.more_vert),
);
```

选择条目后整条菜单先关闭再执行 `onSelect`；带子菜单的条目只展开子菜单。超出视口的菜单限制在安全区内并在面板内滚动；滚动、窗口变化和键盘弹起时跟随目标重新选择方位。

## 当前实现

[桌面](../../../ui/desktop/components/popup_menu/index.dart)：Element 下拉菜单外观。点击或右键打开的菜单接管键盘，上下键跳过禁用项循环切换，右键或回车展开子菜单并聚焦第一项，左键收起，Esc 逐级关闭并交还焦点；悬停打开的菜单不抢焦点。子菜单悬停 150 毫秒展开，斜向移入途中不收起。

[移动](../../../ui/mobile/components/popup_menu/index.dart)：大圆角浮起面板，条目按压变色，子菜单点击在旁侧展开；条目不创建焦点。

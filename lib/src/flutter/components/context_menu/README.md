# ElContextMenu

> 接口评审草案。两端共用菜单项和打开入口，沿用现有上下文菜单基元。

## 菜单项构造

| 参数 | 类型与默认值 | 用途 |
| --- | --- | --- |
| `label` | `String`，必填 | 条目文本 |
| `onSelect` | `VoidCallback?` | 激活可用叶子项时，在整组菜单停止交互后执行 |
| `icon` | `IconData` 或 `Widget`，可空 | 条目图标 |
| `enabled` | `bool = true` | 控制条目是否可以激活 |
| `checked` | `bool?` | 有值时展示勾选状态，由调用方提供 |
| `shortcut` | `String?` | 显示快捷键文字 |
| `children` | `List<ElContextMenuItem>?` | 非空时打开子菜单，子菜单锚定父项 |

```dart
final items = [
  ElContextMenuItem(label: '查看', onSelect: () => debugPrint('查看')),
  ElContextMenuItem.divider(),
  ElContextMenuItem(label: '删除', enabled: false),
];
```

`ElContextMenu` 保留 `const ElContextMenu()` 基类构造，以及 `buildPanel`、`buildItemStyle`、`buildItemContent` 和 `buildDivider` 外观入口。两端共用菜单行为。默认外观拟由调用处的 `ElComponentProvider` 通过 `ElComponents.contextMenu` 提供，类型为 `ElContextMenu?`。查找顺序为显式传入的 `menu`、调用处生效的组件配置、已注册的平台默认外观。 [现有菜单基元](../../widgets/popup/context_menu.dart)

## 调用

```dart
ElContextMenuHandle? showContextMenu(
  BuildContext context, {
  required Offset position,
  required List<ElContextMenuItem> items,
  ElContextMenu? menu,
  ElEventDetails? triggerEvent,
  bool rootOverlay = false,
  ContextMenuInitialFocus initialFocus = .first,
  bool restoreFocus = true,
  VoidCallback? onNavigatePrevious,
  VoidCallback? onNavigateNext,
});
```

```dart
void openNoteMenu(BuildContext context, ElEventDetails event) {
  el.showContextMenu(
    context,
    position: event.globalPosition,
    triggerEvent: event,
    items: [
      ElContextMenuItem(
        label: '收藏',
        onSelect: () => el.toast(context, '已收藏'),
      ),
    ],
  );
}

Builder(
  builder: (context) => ElView(
    event: ElEvent(
      onSecondaryTap: (event) => openNoteMenu(context, event),
      onLongPress: (event) => openNoteMenu(context, event),
    ),
    child: '笔记',
  ),
);
```

`position` 是调用窗口内的全局坐标。`context` 决定窗口、主题和挂载范围。默认取最近 Overlay，`rootOverlay: true` 取同一窗口内可见的根 Overlay，子菜单沿用根菜单的挂载范围。`triggerEvent` 可接续打开菜单的触屏长按。已失效的 context、缺少 Overlay 或缺少可用外观时返回 `null`。

品牌基元的 `open(context, ...)`、`openWithOptions(context, ...)` 继续接受 context 作为首个必填参数。句柄保留 `bool isOpen` 和 `Future<void> closed`，后者在菜单退场摘除时结清。显式关闭拟改为 `void close(BuildContext context)`，从 context 校验所属窗口和 Overlay。重复关闭或 context 无效时直接返回。当前句柄使用 `close()`。 [当前打开入口](../../commons/global.dart) · [当前句柄](../../widgets/popup/menu_overlay.dart)

点击外部或触发源失联时关闭整组。接入宿主后，物理返回先收起最深一层子菜单，最后收起根菜单。键盘关闭后按 `restoreFocus` 将焦点归还给仍有效的来源。

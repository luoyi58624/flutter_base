# ElDropdownMenu

> 接口评审草案，供桌面端和移动端共用。

## 构造

| 参数 | 类型与默认值 | 用途 |
| --- | --- | --- |
| `key` | `Key?` | Widget 标识 |
| `child` | `Object`，必填 | 触发器内容，可用文字、图标或 Widget |
| `items` | `List<ElContextMenuItem>`，必填 | 动作项、子菜单与分隔线 |
| `anchor` | `ElOverlayAnchor = const ElOverlayAnchor(placement: .bottomStart)` | 默认在触发器下方对齐左缘，支持翻转和视口避让 |
| `rootOverlay` | `bool = false` | 默认选最近 Overlay，显式开启时选当前窗口内可见的根 Overlay |
| `disabled` | `bool = false` | 禁止打开菜单 |
| `style` | `ElStyle?` | 菜单面板样式 |
| `event` | `ElEvent?` | 合并到触发器，`preventDefault()` 可阻止默认打开或切换 |
| `semanticLabel` | `String?` | 触发器的辅助名称 |

两端共用 `ElComponents.dropdownMenu`，签名为 `Widget Function(BuildContext context, ElDropdownMenu component)`。菜单项沿用现有 `ElContextMenuItem` 和 `ElContextMenuItem.divider()`。 [菜单项构造](../context_menu/README.md#菜单项构造)

## 调用

```dart
Builder(
  builder: (context) => ElDropdownMenu(
    child: '更多操作',
    items: [
      ElContextMenuItem(
        label: '收藏',
        onSelect: () => el.toast.show('已收藏', context: context),
      ),
      ElContextMenuItem.divider(),
      ElContextMenuItem(
        label: '移动到',
        children: [
          ElContextMenuItem(
            label: '工作',
            onSelect: () => el.toast.show('已移到工作', context: context),
          ),
        ],
      ),
      ElContextMenuItem(label: '删除', enabled: false),
    ],
  ),
);
```

点击或键盘激活时，从触发器挂载处的 context 打开。子菜单锚定父项。选中可用叶子项时，整组菜单先停止交互并开始退场，再调用该项的 `onSelect`。带子项的条目打开下一层，`checked` 可显示调用方提供的勾选状态。表单值选择使用 [ElSelect](../select/README.md)。

再次激活触发器、点击外部或触发器失联时关闭。Escape 和接入宿主的物理返回每次收起一层，从最深子菜单退到根层。菜单全部收起后，下一次返回由宿主交给下层弹层或应用。触发器仍可见且焦点仍属于菜单时，关闭后归还焦点。

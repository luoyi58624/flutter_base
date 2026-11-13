# Drawer

停靠屏幕边缘的抽屉。`el.drawer.show` 在根导航器打开，遮罩、Esc、系统返回与移动端拖动都可关闭。

## 调用

```dart
final status = await el.drawer.show<String>(
  context,
  title: '筛选状态',
  size: 360,
  child: Builder(
    builder: (context) => ElButton(onPressed: () => Navigator.pop(context, '已完成'), child: '已完成'),
  ),
  footer: Builder(
    builder: (context) => ElButton(onPressed: () => Navigator.pop(context, '全部'), child: '重置'),
  ),
);
```

| 参数 | 说明 |
| --- | --- |
| `child` | 正文，超出时独立滚动 |
| `title` / `footer` | 标题与页脚，接受文字或 Widget |
| `placement` | 停靠边缘，默认 right |
| `size` | 抽屉宽度（左右）或高度（上下），省略时由品牌决定，超出视口时收敛到视口 |
| `showClose` | 显示关闭按钮，默认显示 |
| `dismissible` | 为假时只能通过按钮或 `Navigator.pop` 关闭 |

返回值、关闭时机与品牌捕获规则与 [Dialog](../dialog/README.md) 相同。

## 外观与动画

品牌槽位 `drawer`：`Widget Function(BuildContext context, ElDrawer component)`。直接放在页面里时 `onClose` 为空，品牌只返回面板。

现有品牌：

- 桌面：贴边铺满，默认占视口 30% 且不小于 280；标题与关闭按钮在顶部，页脚右对齐；300ms 从对应边缘整体滑入。
- 移动：默认宽 360 或高 420，可从面板或遮罩向停靠边缘拖动关闭；250ms 进退场。

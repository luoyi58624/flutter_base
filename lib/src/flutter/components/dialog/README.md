# Dialog

模态对话框。`el.dialog` 在根导航器打开，自定义对话框、确认框、提示框、输入框与底部面板共用同一套遮罩、返回键与进退场。

## 调用

```dart
final plan = await el.dialog.show<String>(
  context,
  title: '选择套餐',
  child: '选择后可随时升级。',
  footer: Builder(
    builder: (context) => ElButton(onPressed: () => Navigator.pop(context, '专业版'), child: '专业版'),
  ),
);

final accepted = await el.dialog.confirm(context, title: '删除项目', content: '删除后无法恢复。', type: .error);
await el.dialog.alert(context, content: '同步完成');
final name = await el.dialog.prompt(
  context,
  title: '重命名',
  value: '旧名称',
  validator: (value) => value.trim().isEmpty ? '名称不能为空' : null,
);
```

| 方法 | 结果 |
| --- | --- |
| `show<T>(context, {child, title, footer, placement, showClose, dismissible, style, semanticLabel})` | 内容里 `Navigator.pop(context, value)` 的值；遮罩、Esc、返回键与拖动关闭得到 null |
| `confirm(context, {content, title, confirmText, cancelText, type, placement, dismissible})` | 确认得到 true，取消或关闭得到 false |
| `alert(context, {content, title, confirmText, type, placement, dismissible})` | 只有确认按钮，关闭后完成 |
| `prompt(context, {title, content, value, placeholder, validator, confirmText, cancelText, placement, dismissible})` | 确认或回车得到输入值，取消或关闭得到 null |

- `placement` 取 `ElPopupPlacement` 的 center、top、bottom、left、right；bottom 即底部面板，移动端可从面板或遮罩向下拖动关闭，正文有滚动空间时优先滚动。
- `dismissible` 为假时遮罩、Esc、系统返回与拖动都不关闭，只能通过按钮或 `Navigator.pop` 关闭。
- `prompt` 的 `validator` 返回错误文字时面板保留并在输入框下方提示，焦点回到输入框；修改内容后提示清除。
- 结果与官方 `Navigator.pop` 一致：关闭时立即交付并让出栈顶，所以在 `await` 之后紧接着 `Navigator.pop` 关闭的是下一层（例如外层抽屉），两层退场同时进行。路由等品牌退场结束后才移除。
- 打开时用调用处的 `context` 捕获主题与 `ElComponentProvider` 注入的 Builder，局部覆写的品牌在弹层内同样生效。
- `semanticLabel` 省略时取文字标题，作为路由名称供辅助技术读取。

## 外观与动画

品牌槽位 `dialog`：`Widget Function(BuildContext context, ElDialog component)`。

`ElDialog` 是内容声明：`child`、`title`、`footer`、`placement`、`showClose`、`dismissible`、`confirmText`、`cancelText`、`type`、`onConfirm`、`onCancel`、`onClose`、`style`、`event`、`semanticLabel`。提供 `confirmText` 时品牌渲染确认、取消按钮；`footer` 优先于默认按钮。

经 `el.dialog` 打开时 `onClose` 关闭这一层，品牌负责遮罩、面板和进退场；直接放在页面里时 `onClose` 为空，品牌只返回面板，不显示关闭按钮。进退场用 `ElOverlayTransition` 声明，关闭时路由等它退场完再移除。

现有品牌：

- 桌面：Element 外观，标题、正文、右对齐页脚；确认框 420 宽，普通对话框 520 宽；300ms 淡入并从停靠方向位移 20 像素，遮罩同步淡入。
- 移动：居中确认框为大圆角卡片与通栏按钮；上下停靠为底部面板外观，带拖动关闭；250ms 进退场，遮罩带模糊。

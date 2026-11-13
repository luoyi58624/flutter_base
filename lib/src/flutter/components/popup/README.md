# 模态反馈

`ElPopup` 是弹层内容基座，`ElDialog`、`ElDrawer` 提供对应内容声明，`ElToast` 提供非阻塞短提示。品牌外观通过 `ElComponents` 注入。

调用入口均以必选 `BuildContext` 为首参数，捕获调用位置的主题和组件品牌：

```dart
final accepted = await el.dialog<bool>(context,
  title: '删除收藏？',
  child: Text('删除后可以重新添加。'),
  footer: Builder(builder: (context) => ElButton(
    onPressed: () => Navigator.pop(context, true), child: '删除')),
);
el.popup(context, title: '分享', child: shareOptions);
el.drawer(context, placement: ElPopupPlacement.right, child: editor);
el.toast(context, '已保存');
```

模态路由挂在根 `Navigator`，遮罩覆盖分支导航和外层底栏。遮罩颜色与模糊读取调用处的主题，系统返回和 `Navigator.pop` 可关闭面板并返回结果。

底部操作面板四周留 16，最大宽 400，高度最多占视口的 85%。确认框最大宽 420，支持底部和居中。侧向抽屉默认宽 360，纵向抽屉默认高 420，尺寸按系统安全区及输入法占用收敛。正文超出时独立滚动，页脚保持可见。底部面板和抽屉可以沿打开方向向外滑动关闭，触点所在正文能沿该方向滚动时，本次手势交给正文。

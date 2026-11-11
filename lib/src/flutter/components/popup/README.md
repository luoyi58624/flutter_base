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

路由处理遮罩、返回键、输入法避让、底部拖动和业务返回值，不暴露控制句柄。长内容在面板内滚动，页脚保持可见。

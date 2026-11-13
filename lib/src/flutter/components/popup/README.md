# Popup、Dialog、Drawer、Toast

> 接口评审草案。桌面端和移动端共用以下声明与调用方式。当前实现见文末。

## 构造

`ElPopup` 声明底部面板内容。`ElDialog` 和 `ElDrawer` 继承同一套内容参数，分别用于对话框和抽屉。`ElToast` 声明一条短提示。直接构造时，组件在 Widget 树的挂载位置取得 context。

| 构造 | 必填参数 | 可选参数和默认值 |
| --- | --- | --- |
| `ElPopup` | `Widget child` | `Key? key`、`Object? title`、`Object? footer`、`bool showClose = true`、`ElStyle? style`、`ElEvent? event`、`String? semanticLabel` |
| `ElDialog` | `Widget child` | 同 `ElPopup`，`showClose` 默认为 `false` |
| `ElDrawer` | `Widget child` | 同 `ElPopup`，`showClose` 默认为 `true` |
| `ElToast` | `Object child` | `Key? key`、`Object? icon`、`ElStyle? style`、`String? semanticLabel` |

`title` 和 `footer` 接受文字或 Widget。`style` 合并到品牌默认样式之后，面板的 `event` 合并到内容根节点。`showClose` 在有面板关闭作用域时控制关闭按钮。以下示例将内容直接放进当前布局。

```dart
ElPopup(title: '分享', child: Text('选择分享方式'), showClose: false);
ElDialog(title: '删除收藏？', child: Text('删除后可以重新添加。'));
ElDrawer(title: '筛选', child: Text('设置筛选条件'), showClose: false);
ElToast(child: '已保存');
```

四个 Builder 通过 `ElComponentProvider` 读取当前生效的 `ElComponents`。对应字段为 `popup`、`dialog`、`drawer`、`toast`，签名均为 `Widget Function(BuildContext context, 对应组件类型 component)`。两端提供各自的外观。 [组件声明规范](../README.md)

## 打开面板并返回结果

以下为拟定签名，保留现有的 `el.popup`、`el.dialog` 和 `el.drawer` 调用形态。

```dart
Future<T?> popup<T>(
  BuildContext context, {
  required Widget child,
  Object? title,
  Object? footer,
  bool dismissible = true,
  bool draggable = true,
  bool showClose = true,
  ElStyle? style,
  ElEvent? event,
  String? semanticLabel,
});

Future<T?> dialog<T>(
  BuildContext context, {
  required Widget child,
  Object? title,
  Object? footer,
  ElPopupPlacement placement = .center,
  bool dismissible = true,
  bool showClose = false,
  ElStyle? style,
  ElEvent? event,
  String? semanticLabel,
});

Future<T?> drawer<T>(
  BuildContext context, {
  required Widget child,
  Object? title,
  Object? footer,
  ElPopupPlacement placement = .right,
  bool dismissible = true,
  bool showClose = true,
  ElStyle? style,
  ElEvent? event,
  String? semanticLabel,
});

bool closePopup<T>(BuildContext context, [T? result]);
```

- 从调用处的 `context` 找同一窗口的 `ElPopupHost`，并取得该处生效的品牌和主题。宿主仍在时，页面卸载或 Navigator 替换后，已打开的面板继续保留状态。
- Popup 固定在底部。`ElPopupPlacement` 描述视口位置，包含 `center`、`top`、`bottom`、`left`、`right`。`dismissible` 控制遮罩点击和默认 Escape 关闭。Popup 的 `draggable` 控制跟手关闭，Drawer 停靠边缘时沿对应方向拖动关闭。
- 面板内的提交按钮用面板子树的 `context` 调用 `el.closePopup(context, result)`，关闭该 context 所属的面板。首次接受关闭时，打开方的 `Future<T?>` 结清，随后完成退场。取消、遮罩点击、物理返回、拖动关闭及宿主卸载返回 `null`。
- `closePopup` 在接受关闭时返回 `true`。面板已经关闭、context 已失效或找不到对应面板时返回 `false`。提交值必须符合打开时的 `T`，类型不匹配时报错。打开时若 context 已失效或缺少 `ElPopupHost`，Future 以 `null` 结清。调试模式下，宿主缺失会提示安装位置。
- 应用接入系统返回后，返回先处理面板内的菜单层级，再关闭面板。异步按钮回到面板后检查 `context.mounted` 再提交。 [宿主与返回接线](../../widgets/popup/README.md#窗口弹层宿主) · [Flutter BuildContext.mounted](https://api.flutter.dev/flutter/widgets/BuildContext/mounted.html)

```dart
Future<void> showShare(BuildContext context) async {
  await el.popup<void>(
    context,
    title: '分享',
    child: Builder(
      builder: (panelContext) => ElButton(
        child: '完成',
        onPressed: () => el.closePopup(panelContext),
      ),
    ),
  );
}

Future<bool?> confirmRemoval(BuildContext context) => el.dialog<bool>(
  context,
  title: '删除收藏？',
  child: Text('删除后可以重新添加。'),
  footer: Builder(
    builder: (panelContext) => ElButton(
      child: '删除',
      onPressed: () => el.closePopup(panelContext, true),
    ),
  ),
);

Future<String?> chooseSortOrder(BuildContext context) => el.drawer<String>(
  context,
  title: '排序',
  child: Builder(
    builder: (panelContext) => ElButton(
      child: '按更新时间',
      onPressed: () => el.closePopup(panelContext, 'updated'),
    ),
  ),
);
```

## 显示 Toast

```dart
Future<void> toast(
  BuildContext context,
  Object message, {
  Object? icon,
  Duration duration = const Duration(milliseconds: 2200),
  ElStyle? style,
});
```

`el.toast` 默认使用传入 context 在当前窗口可见的根 Overlay，也就是 `rootOverlay: true`。提示从挂载时开始计时，每条独立，到期或 Overlay 卸载后结清 `Future<void>`。context 失效或找不到目标 Overlay 时立即结清。提示允许指针穿透，也放行物理返回。 [Flutter Overlay 查找规则](https://api.flutter.dev/flutter/widgets/Overlay/maybeOf.html)

```dart
Future<void> notifySaved(BuildContext context) => el.toast(context, '已保存');
```

需要状态语义和顶部排列的轻提示使用 [ElMessage](../message/README.md)。

## 当前实现

当前版本的 `el.popup`、`el.dialog`、`el.drawer` 仍通过根 Navigator 打开，使用 `Navigator.pop(panelContext, result)` 关闭。`el.closePopup` 与命令式面板新增的构造参数透传属于上方草案。Toast 已使用根 Overlay。 [组件源码](index.dart) · [当前命令式入口](../../widgets/popup/modal.dart)

底部操作面板四周留 16，最大宽 400，高度最多占视口的 85%。确认框最大宽 420。侧向抽屉默认宽 360，纵向抽屉默认高 420，尺寸按系统安全区及输入法占用收敛。正文超出时独立滚动，页脚保持可见。底部面板和抽屉可从内容区或遮罩向退场方向拖动，触点所在正文能沿该方向滚动时，本次手势交给正文。面板、遮罩和模糊同步跟随拖动与回弹。

```dart
Future<bool?> confirmRemovalNow(BuildContext context) => el.dialog<bool>(
  context,
  title: '删除收藏？',
  child: Text('删除后可以重新添加。'),
  footer: Builder(
    builder: (panelContext) => ElButton(
      child: '删除',
      onPressed: () => Navigator.pop(panelContext, true),
    ),
  ),
);
```

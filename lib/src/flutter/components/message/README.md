# Message

顶部消息，多条消息可同时存在，各自计时关闭。

## 调用

```dart
el.message.show('保存成功', context: context, type: .success);
el.message.show('同步中…', context: context, duration: Duration.zero);
```

| 方法 | 说明 |
| --- | --- |
| `Future<void> show(Object message, {BuildContext? context, ElThemeType type = .info, Duration duration = const Duration(seconds: 3)})` | 显示一条消息，退场移除后完成。`message` 可传文字或 Widget；`duration` 不大于零时保留到用户通过品牌提供的关闭入口关闭 |

- 传入 `context` 时挂到它所在窗口的根 Overlay，并沿用该处的主题与 `ElComponentProvider` 注入的 Builder；省略时使用 `el.navigatorKey` 所在导航器的 Overlay。
- 同一 Overlay 的消息共用一层，导航后该层回到路由之上，不会被之后打开的页面或对话框盖住。
- 新消息的 `messageStack` 与当前层不同时（例如窗口在桌面与移动布局间切换），当前层的消息按原排布退场，新消息另起一层。
- 指针悬停在消息上时暂停计时，移开后重新计时。
- 承载的 Overlay 被卸载时，消息随之结清。

## 外观、动画与排布

两个品牌槽位：

| 槽位 | 签名 | 职责 |
| --- | --- | --- |
| `message` | `Widget Function(BuildContext context, ElMessage component)` | 单条消息的外观和进退场动画 |
| `messageStack` | `Widget Function(BuildContext context, List<Widget> children)` | 排布同一窗口内的全部消息，`children` 按显示先后排列，结果铺满 Overlay |

`ElMessage` 是内容声明：`child`、`type`、`style`、`onClose`。经 `el.message` 显示时 `onClose` 关闭这条消息；直接放在页面里时为空，品牌不提供关闭入口。

Builder 用 `ElOverlayTransition` 决定进退场时长和曲线，关闭时服务等退场完再移除：

```dart
Widget messageBuilder(BuildContext context, ElMessage c) => ElOverlayTransition(
  duration: Duration(milliseconds: 250),
  builder: (context, animation) => SlideTransition(
    position: animation.drive(Tween(begin: Offset(0, -1), end: Offset.zero)),
    child: ElView(child: c.child),
  ),
);

Widget messageStackBuilder(BuildContext context, List<Widget> children) =>
    Align(alignment: .topCenter, child: Stack(children: children));
```

现有品牌：

- 桌面：Element 浅色底，类型色图标和文字，带关闭按钮；自安全区顶部下方 20 像素起居中纵向排列。进场从上方 40 像素滑入并淡入（300ms），退场反向并收起高度，下方消息随之补位。
- 移动：类型色通栏，底色延伸到状态栏后方，内容让出状态栏；固定在顶部，新消息叠在旧消息上方。从顶部向下滑入（250ms），点击通栏关闭。

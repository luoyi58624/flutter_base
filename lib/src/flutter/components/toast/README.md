# Toast

轻提示，同一时间只显示一条。

## 调用

```dart
el.toast.show('已保存', context: context);
el.toast.show('同步中…', context: context, duration: Duration.zero);
el.toast.close();
```

| 方法 | 说明 |
| --- | --- |
| `Future<void> show(Object message, {BuildContext? context, Duration duration = const Duration(seconds: 2)})` | 显示新提示，当前提示同时开始退场；退场移除后完成。`message` 可传文字或 Widget；`duration` 不大于零时保留到 `close` |
| `Future<void> close()` | 关闭当前提示，退场移除后完成 |

- 传入 `context` 时挂到它所在窗口的根 Overlay，并沿用该处的主题与 `ElComponentProvider` 注入的 Builder；省略时使用 `el.navigatorKey` 所在导航器的 Overlay。
- 提示在安全区内居中，避开输入法，不拦截点击，也不参与系统返回。
- 承载的 Overlay 被卸载时，提示随之结清。

## 外观与动画

`ElToast` 是内容声明：`child`、`style`，品牌槽位 `ElComponents.toast`。Builder 用 `ElOverlayTransition` 决定进退场时长和曲线：

```dart
Widget toastBuilder(BuildContext context, ElToast c) => ElOverlayTransition(
  duration: Duration(milliseconds: 200),
  builder: (context, animation) => FadeTransition(opacity: animation, child: ElView(child: c.child)),
);
```

`el.toast.close` 或计时结束时，服务等 `ElOverlayTransition` 退场完再移除。`ElToast` 直接放在页面里时，同一个 Builder 显示终态，不播放动画。

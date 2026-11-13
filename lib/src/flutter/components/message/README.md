# ElMessage

> 接口评审草案，供桌面端和移动端共用。

## 构造

| 参数 | 类型与默认值 | 用途 |
| --- | --- | --- |
| `key` | `Key?` | Widget 标识 |
| `child` | `Object`，必填 | 消息内容，可传文字或 Widget |
| `type` | `ElThemeType = .info` | 信息、成功、警告、错误等语义，颜色由品牌映射 |
| `icon` | `Object?` | 可选前置图标，空值省略 |
| `style` | `ElStyle?` | 在品牌默认样式后合并 |
| `semanticLabel` | `String?` | 辅助技术读取的名称 |

构造得到消息内容 Widget，使用挂载处的 context。两端通过同一个 `ElComponents.message` 槽位提供外观，签名为 `Widget Function(BuildContext context, ElMessage component)`。

```dart
ElMessage(child: '网络暂不可用', type: .warning);
```

## 调用

```dart
Future<void> message(
  BuildContext context,
  Object message, {
  ElThemeType type = .info,
  Object? icon,
  Duration duration = const Duration(seconds: 3),
  ElStyle? style,
  String? semanticLabel,
});
```

```dart
Future<void> notifySynced(BuildContext context) => el.message(
  context,
  '同步完成',
  type: .success,
);
```

`el.message` 默认使用调用处在当前窗口可见的根 Overlay，也就是 `rootOverlay: true`。从调用处解析品牌和主题。多条消息在顶部安全区按出现顺序自上而下排列，按各自的显示时间摘除，剩余消息补位。各窗口的顺序和计时独立。 [Flutter Overlay 查找规则](https://api.flutter.dev/flutter/widgets/Overlay/maybeOf.html)

消息允许指针穿透，放行物理返回。默认时长拟为 3 秒，从消息挂载时开始计算。`Future<void>` 在消息摘除或承载 Overlay 卸载后结清。context 已失效或找不到目标 Overlay 时立即结清。

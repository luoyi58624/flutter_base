# Card

`ElCard` 提供可选的 `child`、`loading`、`style`、`event` 和 `onTap`，通过品牌 `cardBuilder` 分派。标题、说明等内容由调用方在 `child` 中组合。

onTap 或 event.onTap 非空时启用整卡操作，详细识别配置通过 event.config 设置，event.preventDefault 可取消 onTap。移动端默认按压变色并缩放，用户通过 style.onTap 覆写；内部按钮、输入仍独立操作。

卡片默认无阴影。调用方可用 `style.withShadow(...)` 生成投影，也可通过 `style.boxShadow` 传入自定义阴影。

```dart
ElCard(
  style: ElStyle().withShadow(type: .floating, level: ElLevelType.md.shadow(context)),
  child: Text('卡片内容'),
);
```

`loading` 显示指示器并暂停整卡与内容交互，内容实例仍保留。

区域语义由品牌实现建立（可用 semanticLabel 命名），品牌只负责默认外观与反馈。桌面实现无默认外观，移动实现带默认外观。

# ButtonView

无品牌外观的按钮基元，统一指针、键盘与辅助技术激活。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

## 自定义外观

```dart
ElButtonView(
  onPressed: () { debugPrint('保存'); },
  semanticLabel: '保存',
  style: ElStyle(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    backgroundColor: Colors.blue,
    color: Colors.white,
    onHover: ElStyle(backgroundColor: Colors.indigo),
    onTap: ElStyle(opacity: 0.7),
    onDisabled: ElStyle(opacity: 0.4),
  ),
  child: '保存',
);
```

| 参数 | 用途 |
| --- | --- |
| onPressed | 鼠标、键盘、辅助技术共用激活动作 |
| child / style | 内容和完整外观，支持 ElView 的文本、Widget、混排 |
| disabled | 禁用交互；与 event.disabled 合并 |
| semanticLabel | 按钮辅助名称 |
| selected / toggled | 选择语义与布尔开关语义；外观需自己根据业务状态设置 |
| event | 组合自定义事件；onTap 与 onPressed 会组合执行 |
| focusNode | 可选外部焦点节点，由调用方销毁 |

## 开关与键盘按压

```dart
final selected = ValueNotifier(false);
ValueListenableBuilder<bool>(
  valueListenable: selected,
  builder: (_, value, _) => ElButtonView(
    toggled: value,
    onPressed: () => selected.value = !value,
    style: ElStyle(backgroundColor: value ? Colors.blue : Colors.grey),
    child: value ? '已开启' : '已关闭',
  ),
);
```

Enter 在按下和 Flutter 报告重复时激活，Space 在匹配的释放事件激活。声明 `onKeyDown`、`onKeyRepeat` 或 `onKeyUp` 时，由调用方接管整组键盘激活。

Enter、空格的按压态及释放配对由 ElView 内部维护，直接声明 `style.onTap` 即可。Esc、失焦、禁用或卸载会清理按压态。上层皮肤可用 `onTapDown`、`onTapUp`、`onTapCancel` 响应主焦点的激活键。现成反馈可选 [Tap](../../widgets/tap/README.md)。

# ButtonView

无品牌外观的按钮基元，统一指针、键盘与辅助技术激活。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

## 自定义外观

```dart
ElButtonView(
  onPressed: () { debugPrint('保存'); },
  semanticLabel: '保存',
  style: ElStyle(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    bgColor: Colors.blue,
    color: Colors.white,
    onHover: ElStyle(bgColor: Colors.indigo),
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
| pressController | 读取 Space 键按住期间的按压状态，供皮肤同步绘制 |

## 开关与键盘按压

```dart
final selected = ValueNotifier(false);
ValueListenableBuilder<bool>(
  valueListenable: selected,
  builder: (_, value, _) => ElButtonView(
    toggled: value,
    onPressed: () => selected.value = !value,
    style: ElStyle(bgColor: value ? Colors.blue : Colors.grey),
    child: value ? '已开启' : '已关闭',
  ),
);
```

Enter 在 keydown 激活，重复按键可继续激活；Space 在 keyup 激活。自定义 onKeyDown / onKeyRepeat / onKeyUp 任一回调时，整组内建键盘激活让位，需调用方完整接管。

ElButtonViewPressController 的 pressed 只表示 Space 按住会话，不是通用指针按下状态；cancel 取消该会话，不激活按钮。控制器和 notifier 在生命周期内持有并 dispose。普通按钮不依赖 ElComponentProvider；现成反馈可选 [Tap](../../widgets/tap/README.md)。

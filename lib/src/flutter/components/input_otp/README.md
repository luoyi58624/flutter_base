# InputOtp

`ElInputOtp` 声明定长验证码输入，通过 `inputOtpBuilder(context, component)` 提供编辑、分格布局和完成通知。导入与实现登记见 [Components](../README.md)。

```dart
final code = ValueNotifier('');
ElInputOtp(
  modelValue: code,
  length: 6,
  type: ElInputOtpType.outlined,
  onComplete: (value) { debugPrint('验证码：$value'); },
  semanticLabel: '验证码',
);
```

| 参数 | 用途 |
| --- | --- |
| value / modelValue / onChanged | String 值通道，value 与 modelValue 互斥 |
| length | 正整数位数，默认 6 |
| type | outlined、filled、underlined 外观 |
| mask / maskCharacter | 遮挡内容及单个 UTF-16 code unit 的遮挡字符 |
| disabled / autofocus | 禁用与自动聚焦 |
| keyboardType / autofillHints | 默认数字键盘与 oneTimeCode 自动填充提示 |
| onComplete | 输入完成通知，由具体实现触发 |
| style / cellStyle / semanticLabel | 根样式、单格样式和辅助名称 |

公共声明负责位数和遮挡字符的构造检查；输入过滤、粘贴分发、焦点移动和完成判定由 Builder 处理。模型在 State / Hook 生命周期内持有并 dispose。

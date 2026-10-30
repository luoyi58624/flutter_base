# Input

`ElInput` 声明单行、多行输入配置，通过 `inputBuilder(context, component)` 提供编辑、绑定与外观。导入与实现登记见 [Components](../README.md)。

```dart
final text = ValueNotifier('');
ElInput(
  modelValue: text,
  placeholder: '请输入名称',
  clearable: true,
  maxLength: 40,
  showWordLimit: true,
  onSubmitted: (value) { debugPrint(value); },
  semanticLabel: '名称',
);

ElInput(value: '', textarea: true, minLine: 3, maxLine: 8);
```

| 参数 | 用途 |
| --- | --- |
| value / modelValue / onChanged | String 值通道，value 与 modelValue 互斥 |
| placeholder / prefix / suffix | 占位文字与前后内容 |
| disabled / readOnly | 禁用交互与只读模式 |
| clearable / showPassword | 清空入口与密码显示切换 |
| maxLength / inputFormatters / showWordLimit | 长度限制、输入格式化和字数展示 |
| textarea / minLine / maxLine | 多行模式与行数范围；minLine 默认 3 |
| autofocus / focusNode / onKeyEvent | 自动聚焦、外部焦点和键盘拦截 |
| onFocus / onBlur / onSubmitted / onClear | 聚焦、失焦、提交与清空通知 |
| keyboardType / textInputAction / autofillHints | 键盘、动作键和自动填充提示 |
| style / placeholderStyle / affixStyle / actionStyle / width | 根、占位、附加内容和操作入口的样式及宽度 |
| control / semanticLabel | 编辑控制门面与辅助名称 |

## 编辑控制门面

`ElInputController` 提供 `attached`、`controller`、`focusNode`、`hasFocus`，以及 focus、blur、clear、selectAll 操作。未挂载时操作返回 false；同一控制器只能挂载一个输入框，卸载后才能 dispose。

输入连接的 onAction、onConnectionClosed、onPrivateCommand、onFloatingCursor 等回调，以及自动更正、选择、预测和平台输入选项均由声明转交实现。完整字段注释见 [index.dart](index.dart)。公共声明的 `formBindable` 默认 true，具体实现负责表单接入；表单组合见 [Form](../../widgets/form/README.md)。

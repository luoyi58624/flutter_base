# Radio

`ElRadio<T>` 是单选组内的选项，`ElRadio.toggle` 是独立布尔开关；分组模型和上下文由同目录 [group.dart](group.dart) 提供。导入与实现登记见 [Components](../README.md)。

## 单选与自由布局

```dart
final selected = ValueNotifier<String?>('grid');
ElRadioGroup<String>(
  modelValue: selected,
  required: false,
  child: Wrap(spacing: 12, children: [
    ElRadio(value: 'grid', label: '网格'),
    ElRadio(value: 'list', label: '列表'),
  ]),
);
```

| 接口 | 用途 |
| --- | --- |
| ElRadio.value / label | 选项业务值与右侧字符串文案；value 缺省时以 label 为值 |
| ElRadio.disabled | 禁止该选项交互与焦点请求 |
| ElRadio.toggle | 提供 bool value、modelValue、onChanged、disabled；不提供 label |
| ElRadioState.checked / disabled | 传给 radioBuilder 的选中与有效禁用状态 |
| Group.value / modelValue / onChanged | T? 单选模型；null 表示未选择 |
| Group.child | 任意布局与自定义选项子树 |
| Group.required | 默认 true；false 时再次选择当前值可取消 |
| Group.of / maybeOf | 获取最近分组；listen=false 时不订阅重建 |

普通 ElRadio 必须位于 ElRadioGroup 内，键盘分组由 Flutter RadioGroup / RawRadio 处理。公共宿主负责交互和状态，`radio<T>(context, component, state)` 绘制外观。独立 toggle 默认 false，不接入祖先 Group 或表单。

## 自定义选项

仅使用 Group 和自定义 Flutter 组件时，可导入 `package:flutter_base/flutter.dart`，无需登记品牌 Builder。

```dart
ElRadioGroup<String>(
  value: 'grid',
  child: Builder(builder: (context) {
    final scope = ElRadioGroup.of(context);
    return Wrap(spacing: 8, children: [
      for (final value in ['grid', 'list'])
        ChoiceChip(
          label: Text(value),
          selected: scope.modelValue == value,
          onSelected: (_) => scope.modelValue = value,
        ),
    ]);
  }),
);
```

`ElRadioGroupScope` 提供 `widget` 配置和可读写的 `modelValue`，写入同值时遵循 required 的取消规则。of 要求祖先分组存在，maybeOf 在组外返回 null；嵌套时取最近同类组。

自定义选项负责自己的交互、禁用和语义。需要官方单选键盘导航时，组合 `Radio<Object?>` / `RawRadio<Object?>`，与组内官方 RadioGroup 类型一致，或使用内置 ElRadio。

## 表单绑定

```dart
ElForm(
  value: {'layout': 'grid'},
  child: ElFormItem(
    prop: 'layout',
    child: ElRadioGroup<String>(
      child: Wrap(children: [
        ElRadio(value: 'grid', label: '网格'),
        ElRadio(value: 'list', label: '列表'),
      ]),
    ),
  ),
);
```

Group 接入 T? 表单字段，叶子组件只声明选项值。独立使用 Group 时提供 value / modelValue；notifier 在 State / Hook 生命周期内持有并 dispose。多选和数量限制见 [Checkbox](../checkbox/README.md)。

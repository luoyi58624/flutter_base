# Group

Group 提供值绑定和上下文，布局写在 child 中；自定义组件直接读写 Scope，无需登记或继承指定组件。

导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。modelValue 在 State / Hook 生命周期内持有，卸载时 dispose。

## 单选：内置组件与自由布局

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

required 默认为 true；false 时再次选择同值会清空，onChanged 可收到 null。ElRadio 外观由品牌 Builder 提供；键盘分组由 Flutter RadioGroup / RawRadio 处理。

## 单选：自定义外观

```dart
final selected = ValueNotifier<String?>('grid');
ElRadioGroup<String>(
  modelValue: selected,
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

Scope 只有 widget 配置和可读写的 modelValue。自定义组件负责自己的交互、禁用和语义；需要官方单选键盘导航时，使用 ElRadio，或组合 `Radio<Object?>` / `RawRadio<Object?>`，与组内官方 RadioGroup 的类型一致。

## 多选：数量限制与自定义组件

```dart
final selected = ValueNotifier<List<String>>(['flutter']);
ElCheckboxGroup<String>(
  modelValue: selected,
  min: 1,
  max: 2,
  child: Builder(builder: (context) {
    final scope = ElCheckboxGroup.of(context);
    return Wrap(spacing: 8, children: [
      for (final value in ['flutter', 'dart', 'web'])
        FilterChip(
          label: Text(value),
          selected: scope.hasElement(value),
          onSelected: (scope.hasElement(value) ? scope.disabledRemove : scope.disabledAdd)
              ? null
              : (checked) => checked ? scope.addElement(value) : scope.removeElement(value),
        ),
    ]);
  }),
);
```

| Checkbox Scope | 用途 |
| --- | --- |
| modelValue | 读取 List；赋集合替换选择，赋单值切换该值 |
| hasElement / addElement / removeElement | 查询、添加、移除单项，写入保持 List<T> 类型 |
| clear | 清空选择 |
| disabledAdd / disabledRemove | 达到 max / min，供选项决定是否允许交互 |
| widget | 读取 min、max 等分组配置 |

min / max 用于用户交互限制；整体赋值和 clear 可直接重置模型。内置 ElCheckbox 会读取数量限制，自定义组件按上例禁用相应操作。

## 查询与表单

两个 Group 都提供 `of(context, listen: true)` 和 `maybeOf(context, listen: true)`。of 要求存在祖先，maybeOf 在组外返回 null；嵌套时取最近同类组。listen=false 用于事件回调等只需读写值、不需要订阅重建的场景。

```dart
ElForm(
  value: {'checks': <String>[], 'radio': null},
  child: Column(children: [
    ElFormItem(prop: 'checks', child: ElCheckboxGroup<String>(
      child: Wrap(children: [ElCheckbox(value: 'flutter', label: 'Flutter')]),
    )),
    ElFormItem(prop: 'radio', child: ElRadioGroup<String>(
      child: Wrap(children: [ElRadio(value: 'grid', label: '网格')]),
    )),
  ]),
);
```

独立使用给 value 或 modelValue；放在 ElFormItem(prop: ...) 内可直接绑定表单字段。Checkbox 字段为 List<T>，Radio 字段为 T?。独立 ElCheckbox.toggle / ElRadio.toggle 不接入祖先 Group。

实现仍位于 UI 组件目录，两个 group.dart 保持独立库；Form 上游已有的 ui.dart 依赖尚待单独清理。

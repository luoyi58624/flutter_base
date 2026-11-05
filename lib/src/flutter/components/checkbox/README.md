# Checkbox

`ElCheckbox` 是多选组内的选项，`ElCheckbox.toggle` 是独立布尔开关；分组模型和数量限制由同目录 [group.dart](group.dart) 提供。导入与实现登记见 [Components](../README.md)。

## 多选与数量限制

```dart
final selected = ValueNotifier<List<String>>(['flutter']);
ElCheckboxGroup<String>(
  modelValue: selected,
  min: 1,
  max: 2,
  child: Wrap(spacing: 12, children: [
    ElCheckbox(value: 'flutter', label: 'Flutter'),
    ElCheckbox(value: 'dart', label: 'Dart'),
    ElCheckbox(value: 'web', label: 'Web'),
  ]),
);
```

| 接口 | 用途 |
| --- | --- |
| ElCheckbox.value / label | 选项业务值与右侧字符串文案；value 缺省时以 label 为值 |
| ElCheckbox.disabled / indeterminate | 禁止交互与半选展示；组内半选项激活时转为选中 |
| ElCheckbox.toggle | 独立 bool value、modelValue、onChanged、disabled、indeterminate；不提供 label |
| ElCheckboxState.checked / disabled | 传给 checkboxBuilder 的选中与有效禁用状态 |
| Group.value / modelValue / onChanged | List<T> 多选模型 |
| Group.child / min / max | 自由布局与用户交互的最少、最多选择数量 |
| Group.of / maybeOf | 获取最近分组；listen=false 时不订阅重建 |

普通 ElCheckbox 必须位于 ElCheckboxGroup 内；公共宿主合并选项禁用与分组数量限制，`checkbox(context, component, state)` 提供外观。半选配置从 component.indeterminate 读取。toggle 默认 false，不接入祖先 Group 或表单。

## 自定义选项与 Scope

仅使用 Group 和自定义 Flutter 组件时，可导入 `package:flutter_base/flutter.dart`，无需登记品牌 Builder。

```dart
ElCheckboxGroup<String>(
  value: ['flutter'],
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

| Scope 接口 | 用途 |
| --- | --- |
| modelValue | 读取 List；赋集合替换选择，赋单值切换该值 |
| hasElement / addElement / removeElement | 查询、添加、移除单项，写入保持 List<T> 类型 |
| clear | 清空选择 |
| disabledAdd / disabledRemove | 达到 max / min 时供选项决定是否允许交互 |
| widget | 当前 Group 配置 |

min / max 是交互限制；Scope 的整体赋值、增删和 clear 本身不强制数量限制，自定义选项应读取相应标志。of 要求祖先分组存在，maybeOf 在组外返回 null；嵌套时取最近同类组。

## 表单绑定

```dart
ElForm(
  value: {'languages': <String>[]},
  child: ElFormItem(
    prop: 'languages',
    child: ElCheckboxGroup<String>(
      child: Wrap(children: [
        ElCheckbox(value: 'flutter', label: 'Flutter'),
        ElCheckbox(value: 'dart', label: 'Dart'),
      ]),
    ),
  ),
);
```

表单字段使用 List<T>，叶子组件只声明选项值。独立使用 Group 时提供 value / modelValue；notifier 在 State / Hook 生命周期内持有并 dispose。单选模型见 [Radio](../radio/README.md)。

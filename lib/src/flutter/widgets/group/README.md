# Group：目标 API

Group 负责选择、禁用、数量限制、表单与焦点协调；自定义子项负责外观。两个 Group 已是独立 Dart 库，提供 maybeOf；目录迁移和 Item 接口仍为后续目标。

## 当前用法

导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`；当前 ElRadio / ElCheckbox 的外观仍需品牌组件 Builder。

```dart
final checked = ValueNotifier<List<String>>(['flutter']);
ElCheckboxGroup<String>(
  modelValue: checked, min: 1, max: 2,
  spacing: 12,
  children: [
    ElCheckbox(value: 'flutter', label: 'Flutter'),
    ElCheckbox(value: 'dart', label: 'Dart'),
    ElCheckbox(value: 'web', label: 'Web'),
  ],
);

final radio = ValueNotifier<String?>('grid');
ElRadioGroup<String>(
  modelValue: radio,
  children: [ElRadio(value: 'grid', label: '网格'), ElRadio(value: 'list', label: '列表')],
);
```

| API | 当前行为 |
| --- | --- |
| value / modelValue / onChanged | 初值、响应式值、变化回调；外部 notifier 在生命周期内持有并 dispose |
| children | 可包装组内选项，当前选项为 ElCheckbox / ElRadio；value 未传时以 label 作为身份 |
| min / max | Checkbox 最少/最多选择数量；到上限禁用未选项，到下限阻止取消 |
| disabled | 禁用整组，与子项禁用合并 |
| direction / spacing / runSpacing | Wrap 方向、项间距、换行间距；默认横向、0、8 |
| style / semanticLabel | 组布局样式与辅助名称 |
| 表单绑定 | 放进 ElFormItem(prop: ...) 后继承表单值；Checkbox 字段为 List<T>，Radio 字段为 T? |

Radio 维护单一 Tab 入口和方向键导航，禁用项不参与有效选择；独立 ElRadio.toggle / ElCheckbox.toggle 不加入分组。

## maybeOf：读取与操作当前分组

```dart
final selected = ValueNotifier<List<String>>([]);
ElCheckboxGroup<String>(
  modelValue: selected,
  max: 2,
  children: [Builder(builder: (context) {
    final group = ElCheckboxGroup.maybeOf(context)!;
    final checked = group.value.contains('flutter');
    return FilterChip(
      label: Text('Flutter'),
      selected: checked,
      onSelected: group.disabled || group.limitReached(checked)
          ? null : (value) => group.setSelected('flutter', value),
    );
  })],
);
```

| 查询入口 | 返回接口与能力 |
| --- | --- |
| ElCheckboxGroup.maybeOf(context) | ElCheckboxGroupScope：只读 value 列表、disabled、min / max、isLast、limitReached、setSelected |
| ElRadioGroup.maybeOf(context) | ElRadioGroupScope：value、disabled、isLast、select |

组外返回 null，嵌套时读取最近同类组；在后代 build 中查询会订阅状态变化，不要跨构建缓存上下文。isLast 指直接布局项，包装项内的后代共享该值。

Checkbox 的 setSelected 遵循整组禁用与数量限制。Radio 的 select 只接受已登记且启用的选项；ElRadio 已通过内部 ElRadioGroupOption 协议和 Scope 的内部登记、焦点方法接入。该协议目前用于跨库衔接，任意自定义单选项的稳定公共接口仍未确定；调用方负责自身禁用、交互与辅助语义。

## 迁移目标：自定义 Item

**设计草案，尚未实现，以下两段 Item 示例暂不能直接运行。** 新增公开选择协议后，自定义组件无需继承 ElRadio / ElCheckbox：

```dart
final selected = ValueNotifier<List<String>>([]);
ElCheckboxGroup<String>(
  modelValue: selected,
  max: 2,
  children: [
    ElCheckboxGroupItem<String>(
      value: 'flutter',
      builder: (context, item) => FilterChip(
        label: Text('Flutter'),
        selected: item.checked,
        onSelected: item.disabled ? null : item.setSelected,
      ),
    ),
  ],
);
```

```dart
final selected = ValueNotifier<String?>('grid');
ElRadioGroup<String>(
  modelValue: selected,
  children: [
    ElRadioGroupItem<String>(
      value: 'grid',
      builder: (context, item) => Focus(
        focusNode: item.focusNode,
        child: GestureDetector(
          onTap: item.disabled ? null : item.select,
          child: Text(item.checked ? '● 网格' : '○ 网格'),
        ),
      ),
    ),
  ],
);
```

目标 Item 状态只暴露 checked、disabled、isLast 和选择回调；单选额外提供组管理的 focusNode，保留单一 Tab 入口和方向键切换。上例的自定义 GestureDetector 外观仍应按业务补齐辅助语义。

## 依赖与迁移边界

两个 group.dart 已移除 part of；UI 子项改为导入并使用公开 Scope，原 index.dart 继续导出 Group。Radio Group 只依赖内部选项协议，不再导入 ElRadio 或访问它的私有字段。后续迁移涉及这 **4 个实现文件**及导出、测试路径。

相关测试为 selection_test.dart、toggle_test.dart、group_scope_test.dart 和 group_library_test.dart，覆盖原组件行为、上下文查询及独立库导入。

验收时增加不导入 ui.dart、也不使用 ElComponentProvider 的自定义子项测试；同时保留 min/max、禁用、表单、重排、键盘与独立 toggle 的现有行为。Form 上游仍引用 ui.dart，是已有的间接依赖。

目标示例不依赖 UI 外观；Item 类型仍是提案，实际公共导出在实现时确定。

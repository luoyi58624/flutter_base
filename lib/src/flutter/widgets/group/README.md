# Group：目标 API

**设计草案，尚未实现，下面的 Item API 暂不能直接运行。** Group 只负责选择、禁用、数量限制、表单与焦点协调；自定义子项负责外观，不继承 ElRadio / ElCheckbox。

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

迁移范围：两个 group.dart、两个 UI 子项适配文件和公共导出；现有直接消费测试集中在两个文件。Checkbox 需开放私有作用域；Radio 还需去掉对 ElRadio 实例及 _toggle 的依赖。

验收时增加不导入 ui.dart、也不使用 ElComponentProvider 的自定义子项测试；同时保留 min/max、禁用、表单、重排、键盘与独立 toggle 的现有行为。Form 上游仍引用 ui.dart，是已有的间接依赖。

目标示例不依赖 UI 外观；Item 类型仍是提案，实际公共导出在实现时确定。

# Form

导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。ElForm 管 Map 数据，ElFormItem 用 prop 绑定字段并展示校验信息。

## 表单、规则与提交

```dart
final model = ValueNotifier<Map<String, dynamic>>({'name': ''});
ElForm(
  modelValue: model,
  labelWidth: 80,
  rules: {'name': [ElRequiredFormRule(message: '请输入姓名')]},
  child: Builder(builder: (context) => Column(children: [
    ElFormItem(prop: 'name', label: '姓名', child: ElInput()),
    ElButtonView(
      onPressed: () {
        final form = ElForm.of(context);
        if (form.validate()) debugPrint('${form.formData}');
      },
      child: '提交',
    ),
  ])),
);
```

ElInput 外观需要品牌组件 Builder 配置。model 在生命周期内持有并 dispose；所有 prop 对应字段必须预置且类型匹配。ElForm 数据源 value / modelValue 必须二选一，onChanged 接收变化后的整份 Map。

## 读写、校验与重置

| ElFormState API（在子树中 ElForm.of 获取） | 用途 |
| --- | --- |
| formData / dataListenable | 当前模型与数据变化信号 |
| patch(prop, value) | 修改一个字段 |
| updateFormData(map) | 替换整份数据 |
| validate() | 同步校验全部注册字段，返回是否通过 |
| validateField(prop, trigger: ...) | 单字段校验，可筛选触发时机 |
| clearValidate([props]) | 清除全部或指定字段错误 |
| reset() | 恢复当前数据源的初始快照并清除错误 |
| errorMessages / updateErrorMessages(map) | 读取错误或回填服务端错误 |

```dart
final model = ValueNotifier<Map<String, dynamic>>({'name': ''});
model.value = {...model.value, 'name': 'Alice'};
ElForm(modelValue: model, child: Builder(builder: (context) {
  final form = ElForm.of(context);
  return ElButtonView(
    onPressed: () {
      form.patch('name', 'Bob');
      form.updateErrorMessages({'name': '此名称已存在'});
    },
    child: '回填数据与错误',
  );
}));
```

使用替换式更新，不要原地修改 `model.value['name']`，否则不会触发通知。of 的 context 必须来自表单子树；外层同层 context 用 Builder 转发。

## 规则与字段布局

```dart
ElFormRule(
  message: '必须以 A 开头',
  trigger: ElFormRuleTrigger.change,
  validator: (_, value) => value is String && value.startsWith('A'),
);
ElRangeFormRule(min: 2, max: 20, message: '长度为 2～20');
```

| 配置 | 说明 |
| --- | --- |
| ElRequiredFormRule | null、空白字符串、空集合不通过；默认 blur |
| ElRangeFormRule | 字符串/集合比长度，数字比大小；默认 change |
| ElFormRuleTrigger | blur / change / submit；validate 恒跑全部规则，当前规则均为同步校验 |
| Form.rules / Item.rules | 同字段合并，表单级在前；换规则传新集合 |
| labelWidth / labelPosition / labelSuffix | 统一标签布局；位置 left / right / top，Item 可覆盖宽度和位置 |
| Item.required / error | 覆写必填标记或显示外部错误；required 本身不是校验规则 |
| Item.style / labelStyle / errorStyle | 字段、标签和错误文案样式 |

## 自定义通用字段

```dart
class CounterField extends ElFormModelValue<int> {
  CounterField({super.key, super.value, super.modelValue, super.onChanged});

  @override
  Widget obsBuilder(BuildContext context) => ElButtonView(
    onPressed: () => $obs.value++,
    child: '数量：${$obs.value}',
  );
}
```

放进 `ElFormItem(prop: 'count', child: CounterField())`，并预置 `{'count': 0}`，即可双向绑定和触发 change 校验；独立使用可传 value 或 modelValue。失焦时调用 `$formBlurValidate()`；类型转换覆写 coerceFormValue，内部复用的编辑器可用 formBindable=false 避免抢同一个字段。输入型基类另有 ElInputModelValue、ElInputNumModelValue。

**现有依赖：Form 入口仍引用 ui.dart，表单通道迁到 Flutter 后尚未清理这一依赖。**

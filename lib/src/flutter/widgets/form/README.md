# Form

表单与字段通过 prop 绑定同一份模型；Group 和自定义字段都可继承该数据通道。

```dart
final model = ValueNotifier<Map<String, dynamic>>({'name': ''});
ElForm(
  modelValue: model,
  child: ElFormItem(
    prop: 'name',
    label: '姓名',
    child: ElInput(),
  ),
);
```

model 中预置对应字段。自定义字段继承 ElFormModelValue，并通过 $obs 更新值；内置 ElInput 的外观仍需品牌 Builder。

示例省略导入：`package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

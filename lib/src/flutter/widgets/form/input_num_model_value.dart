part of 'index.dart';

/// 数字字段与编辑文本之间的可空数值转换。
abstract class ElInputNumModelValue extends ElInputModelValue<num?> {
  /// 创建数字字段的表单值通道。
  ElInputNumModelValue({super.key, super.value, super.modelValue, super.onChanged});

  @override
  String toTextEditing(num? value) {
    if (value == null) return '';
    return value.toString();
  }

  /// 解析不出数字时给 null 而不是抛：手输途中会出现 `-` / `1.` 这类残缺文本，
  /// 且本方法被表单值宽容转换复用（表单里可能是 'abc'），抛异常会炸掉整棵树。
  @override
  num? toModelValue(String text) {
    if (text.trim().isEmpty) return null;
    return num.tryParse(text);
  }
}

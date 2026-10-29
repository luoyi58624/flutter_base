part of 'index.dart';

/// 输入类表单组件基类：在 [ElFormModelValue]（表单接入）之上约定「模型值 ↔
/// 编辑器文本」的转换契约，[ElSelect]、[ElInput] 等文本型控件继承。编辑器
/// 载体统一使用 el_ui editable 内核并由子类自持，基类不预设具体视图。
abstract class ElInputModelValue<D> extends ElFormModelValue<D> {
  ElInputModelValue({super.key, super.value, super.modelValue, super.onChanged});

  /// value -> editor text
  String toTextEditing(D value) => value.toString();

  /// editor text -> value
  D toModelValue(String text) => text as D;

  /// 文本型控件对表单值宽容：表单 Map 常来自 JSON，`{'age': 18}` 绑到文本框
  /// 时基类的严格 `is D` 会把 int 静默丢弃、输入框显示空。既然子类已声明了
  /// 「文本 ↔ 模型值」的转换契约，就复用它把非匹配值走一遍文本往返。
  @override
  D? coerceFormValue(Object? raw) {
    final direct = super.coerceFormValue(raw);
    if (direct != null || raw == null) return direct;
    try {
      return toModelValue(raw.toString());
    } catch (_) {
      // 转不出来（如 'abc' 喂给数字框）按未声明处理，不用脏值污染编辑器
      return null;
    }
  }
}

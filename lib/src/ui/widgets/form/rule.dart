part of 'index.dart';

/// 规则触发时机。
enum ElFormRuleTrigger {
  /// 字段失去焦点触发
  blur,

  /// 字段值变化触发
  change,

  /// 仅提交校验时触发（[ElFormState.validate] 恒跑全部规则）
  submit,
}

/// 规则校验对象（同步校验）。
class ElFormRule {
  const ElFormRule({required this.validator, required this.message, this.trigger = .change});

  /// 验证函数，返回 false 表示未通过验证
  final bool Function(ElFormRule rule, dynamic value) validator;

  /// 错误文本提示
  final String message;

  /// 触发验证时机
  final ElFormRuleTrigger trigger;
}

/// 必填规则：null / 空白字符串 / 空集合视为未填
class ElRequiredFormRule extends ElFormRule {
  static bool validate(ElFormRule rule, dynamic v) {
    if (v == null) return false;
    if (v is String && v.trim().isEmpty) return false;
    if (v is Iterable && v.isEmpty) return false;
    if (v is Map && v.isEmpty) return false;
    return true;
  }

  const ElRequiredFormRule({super.validator = validate, required super.message, super.trigger = .blur});
}

/// 范围区间规则：字符串 / 集合比长度，数字比大小
class ElRangeFormRule extends ElFormRule {
  static bool validate(ElFormRule rule, dynamic v) {
    assert(rule is ElRangeFormRule);
    rule as ElRangeFormRule;

    if (v == null) return false;

    // 如果是字符串、集合，则判断其长度是否满足条件
    if (v is String || v is Iterable || v is Map) {
      if (v.length < rule.min) return false;
      if (rule.max != null && v.length > rule.max!) return false;
    }

    // 如果是数字，则比较其大小
    if (v is num) {
      if (v < rule.min) return false;
      if (rule.max != null && v > rule.max!) return false;
    }
    return true;
  }

  const ElRangeFormRule({
    super.validator = validate,
    required super.message,
    super.trigger = .change,
    this.min = 0,
    this.max,
  });

  final int min;
  final int? max;
}

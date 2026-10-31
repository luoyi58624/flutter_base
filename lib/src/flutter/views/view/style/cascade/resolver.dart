import 'package:flutter_base/src/flutter/views/view/style/style.dart';

import '../resolved/builder.dart';
import '../resolved/resolved_style.dart';
import '../resolved/inherited_vars.dart';

import 'package:flutter_base/src/flutter/utils/internal/bit_mask.dart';

import '../internal/field_spec.dart';
import 'style_spec.dart';

/// 按优先级应用声明，构建本节点的样式。
/// 未覆写的继承字段组直接借用父级引用，声明按后写覆盖前写处理。
class StyleResolver {
  const StyleResolver._();

  /// 按当前状态与继承样式解析字段。
  static ResolvedStyle resolve({
    required ElStyle? style,
    required ResolvedStyle? parent,
    required int state,
    InheritedVars? previousVars,
  }) {
    final builder = ResolvedStyleBuilder.fromParent(parent);
    void apply(ElStyle style) {
      builder.mergeVars(style.vars);
      for (final entry in specOf(style).values.entries) {
        fieldSpecOf(entry.key).write(builder, entry.value);
      }
    }

    if (style != null) {
      apply(style);
      if ((state & variantStatesMaskOf(style)) != 0) {
        for (final variant in activeVariantsOf(style, state)) {
          apply(variant);
        }
      }
    }
    if (previousVars != null) builder.stabilizeVars(previousVars);
    return builder.build();
  }

  /// 当前层显式声明的继承字段，供后代传播时截断。
  static FieldMask explicitInheritedMask(ElStyle? style) =>
      style == null ? FieldMask.empty : maskAnd(specOf(style).declaredMask, inheritedFieldsMask);
}

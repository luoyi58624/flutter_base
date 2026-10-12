import '../commons/index.dart';
import '../mixins/widget.dart';
import '../obs/index.dart';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

part 'hook.dart';

/// 支持双向绑定的组件类型
enum ElModelValueType {
  /// 支持单个数据的双向绑定
  single,

  /// 支持多个数据的双向绑定
  multi,
}

/// 连接普通值、外部 ValueNotifier 与组件内部状态。
abstract class ElModelValue<D> extends HookWidget with ElWidgetMixin {
  ElModelValue({super.key, this.value, this.modelValue, this.onChanged});

  /// 普通值输入，重建回灌时只同步内部状态，不触发 onChanged。
  final D? value;
  final ValueNotifier<D>? modelValue;

  /// 内部模型变更通知，modelValue 的外部变更也通知一次，value 参数回灌除外。
  final ValueChanged<D>? onChanged;

  static final obsKey = UniqueKey();

  /// 访问 Hook 上下文存储的 obs 响应式对象
  @protected
  Obs<D> get $obs => $get<Obs<D>>(obsKey);

  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    final obs = $set(obsKey, _useModelValue<D>(value, modelValue, onChanged));
    return ListenableBuilder(
      listenable: obs,
      builder: (context, child) => obsBuilder(context),
    );
  }

  /// 构建响应式组件
  @protected
  Widget obsBuilder(BuildContext context);
}

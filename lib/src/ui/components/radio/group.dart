import 'package:flutter/widgets.dart';

import '../../../flutter/state/obs/index.dart';
import '../../../flutter/widgets/form/index.dart';

/// 只提供单选值绑定与上下文，布局由调用方组合。
class ElRadioGroup<T> extends ElFormModelValue<T?> {
  /// 创建单选分组；required 为 false 时可再次点击当前值取消选择。
  ElRadioGroup({super.key, super.value, super.modelValue, super.onChanged, required this.child, this.required = true});

  /// 任意布局与自定义选项子树。
  final Widget child;

  /// 是否保留当前选择；false 时再次选择同值会清空。
  final bool required;

  /// 查找最近分组，listen 控制是否订阅变化，组外返回 null。
  static ElRadioGroupScope? maybeOf(BuildContext context, {bool listen = true}) {
    final inherited = listen
        ? context.dependOnInheritedWidgetOfExactType<_RadioGroupInherited>()
        : context.getInheritedWidgetOfExactType<_RadioGroupInherited>();
    return inherited?.scope;
  }

  /// 读取最近分组，调用处必须位于分组子树内。
  static ElRadioGroupScope of(BuildContext context, {bool listen = true}) {
    final scope = maybeOf(context, listen: listen);
    assert(scope != null, '当前 context 没有找到 ElRadioGroup');
    return scope!;
  }

  @override
  T? get value => $formBound ? coerceFormValue($formState!.formData[$formProp]) : super.value;

  @override
  Widget obsBuilder(BuildContext context) {
    final scope = ElRadioGroupScope<T>._(this, $obs);
    return _RadioGroupInherited(
      scope: scope,
      child: RadioGroup<Object?>(
        groupValue: scope.modelValue,
        onChanged: (value) => scope.modelValue = value as T?,
        child: child,
      ),
    );
  }
}

/// 单选组的模型读写入口，自定义组件无需登记即可选择。
class ElRadioGroupScope<T> {
  ElRadioGroupScope._(this.widget, this._obs);

  /// 当前分组配置。
  final ElRadioGroup<T> widget;
  final Obs<T?> _obs;

  /// 当前选中值，null 表示未选择。
  T? get modelValue => _obs.value;

  /// 修改选中值，按 required 决定同值是否取消选择。
  set modelValue(T? value) => _obs.value = !widget.required && value == _obs.value ? null : value;
}

class _RadioGroupInherited extends InheritedWidget {
  const _RadioGroupInherited({required this.scope, required super.child});

  final ElRadioGroupScope scope;

  @override
  bool updateShouldNotify(_RadioGroupInherited oldWidget) => true;
}

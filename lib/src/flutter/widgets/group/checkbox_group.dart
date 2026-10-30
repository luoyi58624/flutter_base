import 'package:flutter/widgets.dart';

import '../../state/obs/index.dart';
import '../form/index.dart';

/// 只提供多选值绑定与数量限制，布局由调用方组合。
class ElCheckboxGroup<T> extends ElFormModelValue<List<T>> {
  /// 创建多选分组，绑定值为 List，子树可使用任意自定义组件。
  ElCheckboxGroup({super.key, super.value, super.modelValue, super.onChanged, required this.child, this.min, this.max})
    : assert(min == null || min >= 0),
      assert(max == null || max >= 0),
      assert(min == null || max == null || min <= max);

  /// 任意布局与自定义选项子树。
  final Widget child;

  /// 用户交互时允许的最少选择数量。
  final int? min;

  /// 用户交互时允许的最多选择数量。
  final int? max;

  /// 查找最近分组，listen 控制是否订阅变化，组外返回 null。
  static ElCheckboxGroupScope? maybeOf(BuildContext context, {bool listen = true}) {
    final inherited = listen
        ? context.dependOnInheritedWidgetOfExactType<_CheckboxGroupInherited>()
        : context.getInheritedWidgetOfExactType<_CheckboxGroupInherited>();
    return inherited?.scope;
  }

  /// 读取最近分组，调用处必须位于分组子树内。
  static ElCheckboxGroupScope of(BuildContext context, {bool listen = true}) {
    final scope = maybeOf(context, listen: listen);
    assert(scope != null, '当前 context 没有找到 ElCheckboxGroup');
    return scope!;
  }

  @override
  Widget obsBuilder(BuildContext context) =>
      _CheckboxGroupInherited(scope: ElCheckboxGroupScope<T>._(this, $obs), child: child);
}

/// 多选组的模型读写入口，沿用集合增删与数量限制标志。
class ElCheckboxGroupScope<T> {
  ElCheckboxGroupScope._(this.widget, this._obs);

  /// 当前分组配置。
  final ElCheckboxGroup<T> widget;
  final Obs<List<T>> _obs;

  /// 当前选中值列表。
  List<T> get modelValue => _obs.value;

  /// 传集合时替换选择，传单值时切换该值。
  set modelValue(Object? value) {
    if (value is Iterable) {
      _obs.value = List<T>.from(value);
    } else {
      hasElement(value) ? removeElement(value) : addElement(value);
    }
  }

  /// 判断业务值是否已选择。
  bool hasElement(Object? value) => _obs.value.contains(value);

  /// 添加业务值，以新列表触发更新。
  void addElement(Object? value) {
    if (!hasElement(value)) _obs.value = [..._obs.value, value as T];
  }

  /// 移除业务值，以新列表触发更新。
  void removeElement(Object? value) => _obs.value = _obs.value.where((item) => item != value).toList();

  /// 清空所有选择。
  void clear() => _obs.value = <T>[];

  /// 已达到下限，交互选项应禁止继续取消。
  bool get disabledRemove => widget.min != null && modelValue.length <= widget.min!;

  /// 已达到上限，交互选项应禁止继续添加。
  bool get disabledAdd => widget.max != null && modelValue.length >= widget.max!;
}

class _CheckboxGroupInherited extends InheritedWidget {
  const _CheckboxGroupInherited({required this.scope, required super.child});

  final ElCheckboxGroupScope scope;

  @override
  bool updateShouldNotify(_CheckboxGroupInherited oldWidget) => true;
}

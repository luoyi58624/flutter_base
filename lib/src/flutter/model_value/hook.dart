part of 'index.dart';

/// 自动处理普通变量、响应式变量的 Hook 钩子，返回 [ValueNotifier] 类型的响应式变量。
/// 仅 [ElModelValue] 内部使用，不对外暴露。
Obs<D> _useModelValue<D>(
  D? value,
  ValueNotifier<D>? modelValue,
  ValueChanged<D>? onChanged,
) {
  return use(
    _ModelValueHook<D>(
      value: value,
      modelValue: modelValue,
      onChanged: onChanged,
    ),
  );
}

class _ModelValueHook<D> extends Hook<Obs<D>> {
  const _ModelValueHook({this.value, this.modelValue, this.onChanged});

  final D? value;
  final ValueNotifier<D>? modelValue;
  final ValueChanged<D>? onChanged;

  @override
  _ModelValueHookState<D> createState() => _ModelValueHookState<D>();
}

class _ModelValueHookState<D> extends HookState<Obs<D>, _ModelValueHook<D>> {
  late final Obs<D> _obs;
  bool _receivingValue = false;

  void _onChanged() {
    if (_receivingValue) return;
    hook.modelValue?.value = _obs.value;
    hook.onChanged?.call(_obs.value);
  }

  // value 是父级输入，只同步观察者；回调会把派生的全选状态误当成清空整组的命令。
  void _receiveValue(D value) {
    _receivingValue = true;
    try {
      _obs.value = value;
    } finally {
      _receivingValue = false;
    }
  }

  @override
  void initHook() {
    super.initHook();
    final rawObs = hook.modelValue;
    if (rawObs != null) {
      _obs = Obs<D>(rawObs.value);
      rawObs.addListener(_linkRawObs);
    } else {
      _obs = Obs<D>(hook.value as D);
    }
    _obs.addListener(_onChanged);
  }

  /// 给外部响应式变量添加监听，将更新同步到内部的 [_obs] 变量
  void _linkRawObs() {
    assert(
      hook.modelValue != null,
      'ElModelValue Error: _linkRawObs has Exception.',
    );
    final value = hook.modelValue!.value;
    // 内部变更先写 modelValue 时，外部监听会同步回到这里；此时内部 Obs 已是
    // 同值，必须截断回声，否则 onChanged 与全部监听器会被重复通知一次。
    if (_obs.rawValue == value) return;
    _obs.rawValue = value;
    _obs.notify();
  }

  @override
  void didUpdateHook(_ModelValueHook<D> oldHook) {
    super.didUpdateHook(oldHook);
    bool? ignoreValueUpdate; // 如果是 modelValue 发生变更，则不需要更新 value
    if (hook.modelValue != oldHook.modelValue) {
      oldHook.modelValue?.removeListener(_linkRawObs);
      if (hook.modelValue != null) {
        ignoreValueUpdate = true;
        final rawObs = hook.modelValue!;
        rawObs.addListener(_linkRawObs);
        safeCallback(() => _obs.value = rawObs.value);
      }
    }

    if (ignoreValueUpdate != true) {
      if (hook.value != oldHook.value) {
        safeCallback(() => _receiveValue(hook.value as D));
      }
    }
  }

  @override
  void dispose() {
    hook.modelValue?.removeListener(_linkRawObs);
    _obs.removeListener(_onChanged);
    _obs.dispose();
    super.dispose();
  }

  @override
  Obs<D> build(BuildContext context) => _obs;

  @override
  String get debugLabel => '_useModelValue<$D>';
}

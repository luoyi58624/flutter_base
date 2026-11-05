part of 'index.dart';

// 自身构建与外部通知分开，输入回放不重复构建已显示新值的组件。
({Obs<D> obs, Listenable changes}) _useModelValue<D>(
  D? value,
  ValueNotifier<D>? modelValue,
  ValueChanged<D>? onChanged,
) {
  return use(_ModelValueHook<D>(value: value, modelValue: modelValue, onChanged: onChanged));
}

class _ModelValueHook<D> extends Hook<({Obs<D> obs, Listenable changes})> {
  const _ModelValueHook({this.value, this.modelValue, this.onChanged});

  final D? value;
  final ValueNotifier<D>? modelValue;
  final ValueChanged<D>? onChanged;

  @override
  _ModelValueHookState<D> createState() => _ModelValueHookState<D>();
}

class _ModelValueHookState<D> extends HookState<({Obs<D> obs, Listenable changes}), _ModelValueHook<D>> {
  late final _ModelObs<D> _obs;
  final _own = ChangeNotifier();
  int? _skipOwnNotification;
  int? _skipCommandNotification;
  int _pendingVersion = 0;
  late D _pendingPreviousValue;
  bool _pendingCommand = false;
  bool _replayScheduled = false;
  bool _disposed = false;

  void _forward() {
    if (_obs.notificationVersion != _skipOwnNotification) _own.notifyListeners();
  }

  void _onChanged() {
    final version = _obs.notificationVersion;
    if (version == _skipCommandNotification) return;
    final value = _obs.rawValue;
    hook.modelValue?.value = value;
    // 外部模型可在写回时同步规范化；嵌套的新通知已处理后，不再发出外层旧命令。
    if (_obs.notificationVersion != version) return;
    hook.onChanged?.call(value);
  }

  void _publish({required bool skipOwn, required bool notifyCommand}) {
    final previousOwn = _skipOwnNotification;
    final previousCommand = _skipCommandNotification;
    final version = _obs.notificationVersion + 1;
    _skipOwnNotification = skipOwn ? version : null;
    _skipCommandNotification = notifyCommand ? null : version;
    try {
      _obs.notify();
    } finally {
      _skipOwnNotification = previousOwn;
      _skipCommandNotification = previousCommand;
    }
  }

  void _receiveValue(D value, {bool notifyCommand = false}) {
    if (_obs.rawValue == value) {
      // 同帧切换输入通道可保持同值，待回放的命令语义仍以最终通道为准。
      if (atDrawFrame && _replayScheduled && _obs.notificationVersion == _pendingVersion) {
        _pendingCommand = notifyCommand;
      }
      return;
    }
    final previousValue = _obs.rawValue;
    _obs.rawValue = value;
    if (!atDrawFrame) {
      _publish(skipOwn: false, notifyCommand: notifyCommand);
      return;
    }

    // 构建中静默更新供当前子树读取，跨子树观察者仍在帧后安全通知。
    if (!_replayScheduled || _obs.notificationVersion != _pendingVersion) {
      _pendingPreviousValue = previousValue;
    }
    _pendingVersion = _obs.notificationVersion;
    _pendingCommand = notifyCommand;
    if (_replayScheduled) return;
    _replayScheduled = true;
    nextTick(() {
      _replayScheduled = false;
      if (_disposed || _obs.notificationVersion != _pendingVersion || _obs.rawValue == _pendingPreviousValue) {
        return;
      }
      _publish(skipOwn: true, notifyCommand: _pendingCommand);
    });
  }

  @override
  void initHook() {
    super.initHook();
    final rawObs = hook.modelValue;
    if (rawObs != null) {
      _obs = _ModelObs<D>(rawObs.value);
      rawObs.addListener(_linkRawObs);
    } else {
      _obs = _ModelObs<D>(hook.value as D);
    }
    _obs.addListener(_onChanged);
    _obs.addListener(_forward);
  }

  /// 给外部响应式变量添加监听，将更新同步到内部的 [_obs] 变量
  void _linkRawObs() {
    assert(hook.modelValue != null, 'ElModelValue Error: _linkRawObs has Exception.');
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
    if (hook.modelValue != oldHook.modelValue) {
      oldHook.modelValue?.removeListener(_linkRawObs);
      if (hook.modelValue != null) {
        final rawObs = hook.modelValue!;
        rawObs.addListener(_linkRawObs);
        _receiveValue(rawObs.value, notifyCommand: true);
      } else if (hook.value != null || null is D) {
        _receiveValue(hook.value as D);
      }
    } else if (hook.value != oldHook.value) {
      _receiveValue(hook.value as D);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    hook.modelValue?.removeListener(_linkRawObs);
    _obs.removeListener(_onChanged);
    _obs.removeListener(_forward);
    _obs.dispose();
    _own.dispose();
    super.dispose();
  }

  @override
  ({Obs<D> obs, Listenable changes}) build(BuildContext context) => (obs: _obs, changes: _own);

  @override
  String get debugLabel => '_useModelValue<$D>';
}

class _ModelObs<D> extends Obs<D> {
  _ModelObs(super.value);

  int notificationVersion = 0;

  @override
  void notify() {
    // 重入写入属于新通知；不能因仍在旧值回放的调用栈中而吞掉它。
    notificationVersion++;
    super.notify();
  }
}

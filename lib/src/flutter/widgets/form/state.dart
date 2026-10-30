part of 'index.dart';

/// 表单字段注册信息：item 级规则 + 聚焦句柄（scrollToError / 首错聚焦预留，
/// v1 只存不用）。
class _FormFieldRegistration {
  // ignore: unused_element_parameter — focus 为 scrollToError 预留接线位
  _FormFieldRegistration({this.rules, this.focus});

  final List<ElFormRule>? rules;
  final VoidCallback? focus;
}

/// 表单**命令式 API 门面**：经 [useHookState] 挂进 hook 生命周期（随 ElForm
/// 卸载自动 dispose），子树内经 [ElForm.of] 获取。
///
/// 数据是**值语义**：写入 = 整表替换（[updateFormData] / [patch] 或直接替换
/// modelValue 的 Map），读经 `Obs.value` 对 [ObsBuilder] 依赖收集透明；
/// 就地改 Map 不通知——要刷新就替换整个 Map 对象。
class ElFormState extends ElHookState {
  ElForm? _form;
  Obs<Map<String, dynamic>>? _data;
  late Map<String, dynamic> _snapshot;

  final _errorMessages = Obs<Map<String, String>>({});
  final Map<String, _FormFieldRegistration> _fields = {};

  // ===========================================================================
  // 数据访问
  // ===========================================================================

  /// 访问表单数据
  Map<String, dynamic> get formData => _data!.value;

  /// 更新表单数据（整表替换）
  void updateFormData(Map<String, dynamic> newFormData) {
    _data!.value = newFormData;
  }

  /// 更新单个字段（组件同步值的便捷入口，内部仍是整表替换）
  void patch(String prop, dynamic value) {
    if (formData[prop] == value && formData.containsKey(prop)) return;
    updateFormData({...formData, prop: value});
  }

  /// 访问错误消息
  Map<String, String> get errorMessages => _errorMessages.value;

  /// 更新错误消息，你可以直接塞入服务端错误，它会自动更新 UI 上的错误信息
  void updateErrorMessages(Map<String, String> newErrorMessages) {
    _errorMessages.value = newErrorMessages;
  }

  /// 表单数据变化的监听句柄（表单字段组件做数据源→自身状态同步用）。
  /// 静态类型收窄为 [Listenable]：只能挂监听，写不出任何数据操作。
  Listenable get dataListenable => _data!;

  /// 每次 build 由 [ElForm.build] 刷新宿主引用；modelValue 实例更换（换表单）
  /// 时重建 reset 快照——绑定层镜像跨源保持同一内部 obs，须按 widget 上的
  /// modelValue 身份判断，不能只比 data 身份。
  void _attach(ElForm form, Obs<Map<String, dynamic>> data) {
    final modelSwapped = _form != null && !identical(_form!.modelValue, form.modelValue);
    _form = form;
    if (_data == null || !identical(_data, data) || modelSwapped) {
      _data = data;
      _snapshot = Map.from(data.value);
    }
  }

  @override
  void dispose() {
    _errorMessages.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 校验
  // ===========================================================================

  /// 提交语义全量校验：跑全部已注册字段的全部规则（无视 trigger）。
  /// 全部通过返回 true。
  bool validate() {
    var ok = true;
    for (final prop in _fields.keys.toList()) {
      if (!validateField(prop)) ok = false;
    }
    return ok;
  }

  /// 单字段校验。[trigger] 非 null 时只跑对应时机的规则；该时机无规则时不动
  /// 既有错误状态、直接通过（官方 async-validator 口径）。
  bool validateField(String prop, {ElFormRuleTrigger? trigger}) {
    final rules = _rulesFor(prop).where((r) => trigger == null || r.trigger == trigger);
    if (rules.isEmpty) return true;

    String? msg;
    for (final rule in rules) {
      if (rule.validator(rule, formData[prop]) != true) {
        msg = rule.message;
        break;
      }
    }
    if (msg == null) {
      _errorMessages.value.remove(prop);
      _errorMessages.notify();
    } else {
      _errorMessages.value[prop] = msg;
      _errorMessages.notify();
    }
    return msg == null;
  }

  /// 清除校验错误；[props] 为 null 时清全部。
  void clearValidate([List<String>? props]) {
    if (props == null) {
      _errorMessages.value.clear();
    } else {
      _errorMessages.value.removeWhere((k, _) => props.contains(k));
    }
    _errorMessages.notify();
  }

  /// 重置表单：数据回挂载时的快照拷贝 + 清全部错误。
  void reset() {
    _errorMessages.value.clear();
    _errorMessages.notify();
    updateFormData(Map.from(_snapshot));
  }

  /// prop 的生效规则 = 表单级 rules[prop] + item 级 rules（表单级在前）。
  List<ElFormRule> _rulesFor(String prop) {
    return [...?_form?.rules?[prop], ...?_fields[prop]?.rules];
  }

  // ===========================================================================
  // 字段注册（ElFormItem 驱动）
  // ===========================================================================

  void _register(String prop, _FormFieldRegistration registration) {
    _fields[prop] = registration;
  }

  /// 注销只摘注册表、不动 errorMessages——移除 key 会 notify，而注销可能发生
  /// 在 build / dispose 期；残留错误随 item 卸载无处显示，无害。
  void _unregister(String prop, _FormFieldRegistration registration) {
    if (identical(_fields[prop], registration)) _fields.remove(prop);
  }
}

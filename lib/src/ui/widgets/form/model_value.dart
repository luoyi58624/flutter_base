part of 'index.dart';

/// 表单接入基类：表单组件继承它即接入 [ElForm] 体系——**核心是数据同步**：
/// 组件放在 [ElFormItem] 内（[prop] 由 ElFormItem 持有）时，组件的响应式值
/// 与表单 Map 双向直连：
/// - 组件改 `$obs` → 替换式写入表单（`{...formData, prop: v}`）+ change 校验；
/// - 外部替换表单 Map → 回灌 `$obs`，组件自动重建；
/// - 同时把 prop 注册进表单，validate 全量校验覆盖裸 prop 字段。
///
/// **value getter 覆写（干掉组件构造兜零值的根）**：[ElModelValue.build] 构造
/// hook 时读到的 `value` 是多态 getter——prop 模式返回祖先表单值（Obs 初值
/// 非空、首帧即真值），非 prop 模式返回组件自身传的 value。组件因此不再需要
/// `value ?? 兜零值`，纯 prop 表单绑定也不依赖构造给默认值。
///
/// 错误状态统一写入 [ElFormState.errorMessages]；错误消息的布局与展示由
/// [ElFormItem] 承担。
/// 无 ElFormItem 时行为与 [ElModelValue] 完全一致。
abstract class ElFormModelValue<D> extends ElModelValue<D> {
  ElFormModelValue({super.key, super.value, super.modelValue, super.onChanged})
    : assert(value == null || modelValue == null, 'value 与 modelValue 互斥，二选一');

  static final _formKey = UniqueKey();
  static final _propKey = UniqueKey();

  /// 生效的表单 state（祖先无 ElForm 为 null）
  @protected
  ElFormState? get $formState => $get<ElFormState?>(_formKey);

  /// 生效的数据 key（所在 [ElFormItem] 的 prop）
  @protected
  String? get $formProp => $get<String?>(_propKey);

  /// 是否已接入表单（有 ElForm 且有 prop）
  @protected
  bool get $formBound => $formState != null && $formProp != null;

  /// **值通道是否必须**：默认必须给 value / modelValue 或放 ElFormItem(prop)
  /// 内；无值通道的继承者（如纯 UI 的 [ElButtonGroup] 普通组）覆写为 false 放行。
  @protected
  bool get valueChannelRequired => true;

  /// **覆写 [ElModelValue.value]（多态分发）**：prop 模式取祖先表单值作 hook
  /// 初值——`_useModelValue` 的 `null as D` 崩点在纯 prop 场景不再触发；
  /// 非 prop 模式回落构造传入的自身值。缓存由 [build] 开头 $set 先落位。
  @override
  D? get value {
    final p = $formProp;
    if (p == null) return super.value;
    final v = coerceFormValue($formState!.formData[p]);
    assert(v != null, 'ElForm model 字段 $p 的类型与组件 D 不匹配（coerceFormValue 返回 null）');
    return v;
  }

  /// **表单值 → 模型值的转换钩子**：默认只收类型完全匹配的值。
  ///
  /// 数值型组件必须覆盖它——表单 Map 常来自 JSON，里面的 `4` 是 `int`，
  /// 而组件的 D 往往是 `double`，`4 is double` 为 false 会让表单值被静默丢弃。
  @protected
  D? coerceFormValue(Object? raw) => raw is D ? raw : null;

  /// blur 时机校验，输入类组件失焦时调用
  @protected
  void $formBlurValidate() {
    if ($formBound) $formState!.validateField($formProp!, trigger: .blur);
  }

  /// **复合组件的内层编辑器要覆盖成 false**：本基类会隐式继承
  /// 所在 [ElFormItem] 的 prop，所以像 [ElInputNumber] 这种内部复用
  /// [ElInput] 的组件，内层会与外层抢同一个表单字段——外层写回数字、
  /// 内层随后写回字符串，formData 里就成了 '6' 而不是 6。
  ///
  /// 覆盖为 false 后该实例彻底不碰表单，值只经它自己的 value/onChanged 流转。
  @protected
  bool get formBindable => true;

  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    // getter 依赖 hook 缓存，先落位再断言（断言里访问的 value 已是新缓存）
    final form = $set(_formKey, formBindable ? ElForm.maybeOf(context) : null);
    final effProp = $set(_propKey, formBindable ? ElFormItem.maybeOf(context) : null);
    assert(effProp == null || form != null, '设置 prop 的组件必须放在 ElForm 内');
    assert(effProp == null || form!.formData.containsKey(effProp), 'ElForm model 缺少字段 $effProp，请在初始数据里预置');
    assert(
      effProp != null || value != null || modelValue != null || !valueChannelRequired || null is D,
      '组件必须给 value / modelValue，或放在 ElFormItem(prop) 内',
    );
    Widget result = super.build(context);
    final obs = $obs;

    useEffect(() {
      if (form == null || effProp == null) return null;

      // 注册进表单让 validate 覆盖裸 prop 字段；ElFormItem 已注册（携 item 级
      // 规则）时不得覆盖，注销走 identity 复核
      _FormFieldRegistration? registration;
      if (form._fields[effProp] == null) {
        registration = _FormFieldRegistration();
        form._register(effProp, registration);
      }

      // 组件 → 表单：替换式写入 + change 校验；等值直接短路（回灌回声在此截断）
      void syncOut() {
        if (form.formData[effProp] == obs.value) return;
        form.patch(effProp, obs.value);
        form.validateField(effProp, trigger: .change);
      }

      // 表单 → 组件：外部替换 Map 后按 key 回灌；转换不出值 / 缺 key 不动组件值
      void syncIn() {
        final data = form.formData;
        if (!data.containsKey(effProp)) return;
        final v = coerceFormValue(data[effProp]);
        if (v != null && v != obs.value) obs.value = v;
      }

      obs.addListener(syncOut);
      form.dataListenable.addListener(syncIn);
      // 初始以表单数据为准对齐：modelValue 优先场景下 hook 初值来自
      // modelValue（非 prop），此处 rawValue 静默直写覆盖成表单值——本效果在
      // build 期执行，依赖该 obs 的渲染同帧稍后才读值，首帧直接呈现表单值
      //（微任务延后会闪一帧组件零值，switch false→true 事故）；对齐不算变更，
      // 不触发 onChanged/modelValue 镜像
      final initial = form.formData;
      if (initial.containsKey(effProp)) {
        final v = coerceFormValue(initial[effProp]);
        if (v != null) obs.rawValue = v;
      }
      return () {
        obs.removeListener(syncOut);
        form.dataListenable.removeListener(syncIn);
        if (registration != null) form._unregister(effProp, registration);
      };
    }, [form, effProp, obs]);

    return result;
  }
}

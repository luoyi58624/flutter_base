import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../components/button_group/index.dart' show ElButtonGroup;
import '../../components/index.dart' show ElComponentProvider;
import '../../components/input/index.dart' show ElInput;
import '../../components/input_number/index.dart' show ElInputNumber;
import '../../components/select/index.dart' show ElSelect;
import '../../hooks/hook_state.dart' show ElHookState, useHookState;
import '../../utils/model_value/index.dart' show ElModelValue;
import '../../utils/obs/index.dart' show Obs, ObsBuilder;
import '../../utils/platform/index.dart' show ElPlatform;
import '../../views/view/style/style.dart' show ElStyle;
import '../../views/view/view.dart' show ElView;

part 'form_item.dart';
part 'model_value.dart';
part 'input_model_value.dart';
part 'input_num_model_value.dart';
part 'rule.dart';
part 'state.dart';

/// label 布局位置（对齐 element-plus label-position）。
enum ElFormLabelPosition { left, right, top }

/// 表单容器：绑定响应式 Map 数据 + 规则校验 + label 布局上下文。
///
/// 表单数据是**值语义**：要让 UI 刷新就替换整个 Map 对象，99% 的写入由组件
/// 承担（用户操作组件 → 组件在底层替换式更新并发起通知）：
/// ```dart
/// final form = useObs<Map<String, dynamic>>({'username': '', 'password': ''});
/// ElForm(
///   modelValue: form,
///   rules: {'username': [ElRequiredFormRule(message: '请输入用户名')]},
///   labelWidth: 80,
///   child: ElView(child: [
///     ElFormItem(label: '用户名', prop: 'username', child: ElInput()),
///   ]),
/// );
/// form.value = {...form.value, 'username': 'admin'};  // 手动改值：替换整个 Map
/// if (ElForm.of(context).validate()) ...;             // 命令式 API：Builder/子树内 of 获取
/// ```
class ElForm extends ElModelValue<Map<String, dynamic>> {
  /// 数据绑定三件套（value / modelValue / onChanged）由 [ElModelValue]
  /// 体系承担，本类零手搓绑定：
  /// - value：初始数据（hook 按实例比较跟踪 value 变更，rebuild 传新实例视为换数据）；
  /// - modelValue：响应式数据（推荐 `useObs` 创建），外部读写全响应；
  /// - onChanged：任意字段变化回调整份 Map。
  ElForm({
    super.key,
    super.value,
    super.modelValue,
    super.onChanged,
    this.rules,
    this.labelWidth,
    this.labelPosition = .right,
    this.labelSuffix,
    required this.child,
  }) : assert((value == null) != (modelValue == null), 'ElForm 数据源必须且只能提供一个：value（普通 Map）或 modelValue（响应式 Map）');

  /// 表单级校验规则，key 对应 model 数据 key；与 [ElFormItem.rules] 合并
  /// （表单级在前）。换规则 = 传新 Map 实例（值语义），校验与星号即跟随。
  final Map<String, List<ElFormRule>>? rules;

  /// label 宽度；null 时各 item 按内容自然宽（统一对齐请显式给宽）。
  final double? labelWidth;

  final ElFormLabelPosition labelPosition;

  /// label 后缀（如 '：'），仅拼接显示。
  final String? labelSuffix;

  final Widget child;

  /// 子树内获取表单命令式 API（validate / reset / formData / errorMessages…）。
  /// 与表单同层构建时用 Builder 转发 context。
  static ElFormState of(BuildContext context) {
    final result = maybeOf(context);
    assert(result != null, '当前 context 没有找到 ElForm 祖先，如果表单与调用处同层，请使用 Builder 转发 context 对象');
    return result!;
  }

  static ElFormState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_FormScope>()?.state;
  }

  static final _stateKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final result = super.build(context);
    // 命令式 API 门面挂 hook 生命周期（useHookState 自动 dispose），
    // 每次 build 刷新宿主引用；数据实例更换时 _attach 内部重建 reset 快照
    final state = $set(_stateKey, useHookState(ElFormState.new, ignoreListener: true));
    state._attach(this, $obs);
    return result;
  }

  @override
  Widget obsBuilder(BuildContext context) {
    return _FormScope(
      state: $get<ElFormState>(_stateKey),
      rules: rules,
      labelWidth: labelWidth,
      labelPosition: labelPosition,
      labelSuffix: labelSuffix,
      child: child,
    );
  }
}

/// 表单上下文：state（hook 生命周期的命令式 API 门面）引用 + label 布局
/// 配置快照。配置逐字段比较——state 是恒定实例，配置必须快照到自身字段
/// 才能驱动 updateShouldNotify。
class _FormScope extends InheritedWidget {
  const _FormScope({
    required this.state,
    required this.rules,
    required this.labelWidth,
    required this.labelPosition,
    required this.labelSuffix,
    required super.child,
  });

  final ElFormState state;

  /// widget.rules 的身份快照：规则整表替换（值语义）时驱动 updateShouldNotify，
  /// 让 const 子树里的 ElFormItem 必填星号跟上新规则。
  final Map<String, List<ElFormRule>>? rules;

  final double? labelWidth;
  final ElFormLabelPosition labelPosition;
  final String? labelSuffix;

  @override
  bool updateShouldNotify(_FormScope oldWidget) {
    return !identical(rules, oldWidget.rules) ||
        labelWidth != oldWidget.labelWidth ||
        labelPosition != oldWidget.labelPosition ||
        labelSuffix != oldWidget.labelSuffix;
  }
}

/// 表单字段上下文：由 [ElFormItem] 下发，表单字段组件（ElInput 等）经
/// [ElFormItem.maybeOf] 读取 prop 完成绑定、触发校验与错误态样式。
class _FormItemScope extends InheritedWidget {
  const _FormItemScope({required this.form, required this.prop, required super.child});

  /// 所属表单 state。
  final ElFormState form;

  /// 绑定的 model 数据 key；null 表示该 item 不参与数据绑定。
  final String? prop;

  @override
  bool updateShouldNotify(_FormItemScope oldWidget) {
    return !identical(form, oldWidget.form) || prop != oldWidget.prop;
  }
}

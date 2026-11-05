/// 参照：D:/project/html/my-ui/packages/vue/components/Switch.vue；packages/core/my-ui.js:1358-1376；my-ui.css:544-579。
library;

import 'package:flutter/widgets.dart';

import '../../../../flutter/commons/theme/index.dart' show ElThemeContextExt;
import '../../../../flutter/components/switch/index.dart' show ElSwitch;
import '../../../../flutter/utils/obs/index.dart' show Obs;
import '../../../../flutter/views/view/style/style.dart' show ElStyle, ElTransform, ElTransition, ElTransitionField;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../internal/common.dart';
import '../loading/index.dart';

/// 使用移动端开关皮肤实现通用开关声明，值由公共模型持有。
Widget switchBuilder(BuildContext context, ElSwitch component, Obs<bool> model) => _CommonSwitch(component, model);

class _CommonSwitch extends StatelessWidget {
  const _CommonSwitch(this.component, this.model);

  final ElSwitch component;
  final Obs<bool> model;

  @override
  Widget build(BuildContext context) {
    final current = model.value;
    final theme = context.elTheme;
    const height = 28.0;
    const gap = 3.0;
    const thumb = height - 2 * gap;
    final reduced = reducedMotion(context);
    final thumbVisual = ElView(
      style: ElStyle(
        width: thumb,
        height: thumb,
        alignment: .center,
        borderRadius: BorderRadius.circular(999),
        backgroundColor:
            ElView.maybeOf(context)?.getVar<Color>(Switch.$thumbBackground) ??
            (current ? theme.primaryText : const Color(0xffffffff)),
        boxShadow: [
          BoxShadow(color: const Color(0xff000000).withValues(alpha: .12), offset: const Offset(0, 2), blurRadius: 5),
        ],
        transition: reduced ? const [] : const [ElTransition.all(Duration(milliseconds: 150), Curves.ease)],
      ),
      child: component.loading ? const ExcludeSemantics(child: Loading(size: LoadingSize.small)) : null,
    );
    return inline(
      ActionView(
        style: ElStyle(
          width: height * 47 / 28,
          height: height,
          padding: const EdgeInsets.all(gap),
          borderRadius: BorderRadius.circular(999),
          backgroundColor: current ? theme.primary : theme.gray,
          transition: reduced ? const [] : const [ElTransition.all(Duration(milliseconds: 230), Curves.ease)],
        ).merge(component.style),
        label: component.semanticLabel,
        button: false,
        toggled: current,
        focusNode: component.focusNode,
        event: component.event,
        disabled: component.disabled,
        blocked: component.loading,
        activateOnEnter: false,
        delayTouchUp: Duration.zero,
        onActivate: (_) => model.value = !current,
        child: AnimatedAlign(
          alignment: current ? .centerRight : .centerLeft,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 230),
          curve: Curves.ease,
          child: thumbVisual,
        ),
      ),
    );
  }
}

/// 47×28 的开关，默认支持指针和辅助技术，显式配置焦点后支持 Space。
class Switch extends StatelessWidget {
  /// 局部开关滑块背景。
  static const $thumbBackground = 'switch.thumbBackground';

  /// value或modelValue必须提供其一，label不绘制为可见文字。
  const Switch({
    super.key,
    this.value,
    this.modelValue,
    required this.label,
    this.disabled = false,
    this.onChanged,
    this.focusNode,
  }) : assert(value != null || modelValue != null),
       assert(value == null || modelValue == null, 'value 与 modelValue 互斥');

  /// 外部状态。
  final bool? value;

  /// 双向状态源。
  final ValueNotifier<bool>? modelValue;

  /// 辅助名称。
  final String label;

  /// 禁止切换，保留Web默认配色和透明度。
  final bool disabled;

  /// 用户切换后的值。
  final ValueChanged<bool>? onChanged;

  /// 调用方拥有的焦点节点。
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) => ValueBuilder<bool>(
    value: value ?? false,
    notifier: modelValue,
    onChanged: onChanged,
    builder: (context, current, change) {
      final t = context.elTheme;
      final transitions = reducedMotion(context)
          ? <ElTransition>[]
          : const [ElTransition.all(Duration(milliseconds: 230), Curves.ease)];
      return inline(
        ActionView(
          label: label,
          button: false,
          toggled: current,
          focusNode: focusNode,
          disabled: disabled,
          activateOnEnter: false,
          delayTouchUp: Duration.zero,
          onActivate: (_) => change(!current),
          style: ElStyle(
            width: 47,
            height: 28,
            padding: const EdgeInsets.all(3),
            alignment: Alignment.centerLeft,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: current ? t.primary : t.gray,
            transition: transitions,
          ),
          child: ElView(
            style: ElStyle(
              width: 22,
              height: 22,
              borderRadius: BorderRadius.circular(99),
              backgroundColor:
                  ElView.maybeOf(context)?.getVar<Color>(Switch.$thumbBackground) ??
                  (current ? t.primaryText : const Color(0xffffffff)),
              transform: ElTransform.translate(current ? 19 : 0, 0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff000000).withValues(alpha: .12),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                ),
              ],
              transition: reducedMotion(context)
                  ? const []
                  : const [
                      ElTransition.field(ElTransitionField.transform, Duration(milliseconds: 230), Curves.ease),
                      ElTransition.field(ElTransitionField.backgroundColor, Duration(milliseconds: 150), Curves.ease),
                    ],
            ),
          ),
        ),
      );
    },
  );
}

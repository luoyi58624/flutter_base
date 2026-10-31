/// 参照：D:/project/html/my-ui/packages/vue/components/Switch.vue；packages/core/my-ui.js:1358-1376；my-ui.css:544-579。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';
import '../loading/index.dart';

/// 使用移动端开关皮肤实现通用值通道，并连接祖先表单字段。
Widget mySwitchBuilder(BuildContext context, ElSwitch component) =>
    _CommonSwitch(component);

class _CommonSwitch extends ElFormModelValue<bool> {
  _CommonSwitch(this.component)
    : super(
        value: component.value,
        modelValue: component.modelValue,
        onChanged: component.onChanged,
      );

  final ElSwitch component;

  @override
  bool? get value => super.value ?? false;

  @override
  Widget obsBuilder(BuildContext context) {
    final current = $obs.value;
    final theme = context.elTheme;
    final height = component.height ?? 28;
    final gap = component.gap ?? 3;
    final thumb = (height - 2 * gap).clamp(0.0, double.infinity);
    final width = (height * (component.widthAspect ?? 47 / 28)).clamp(
      height,
      double.infinity,
    );
    final reduced = myReducedMotion(context);
    final content = current
        ? component.activeContent
        : component.inactiveContent;
    final actionContent = current
        ? component.activeActionContent
        : component.inactiveActionContent;
    final thumbVisual = ElView(
      style: ElStyle(
        width: thumb,
        height: thumb,
        alignment: .center,
        borderRadius: BorderRadius.circular(999),
        backgroundColor:
            ElView.maybeOf(context)?.getVar<Color>(MySwitch.$thumbBackground) ??
            (current ? theme.primaryText : const Color(0xffffffff)),
        color: current ? theme.primary : theme.textSecondary,
        boxShadow: [
          BoxShadow(
            color: const Color(0xff000000).withValues(alpha: .12),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
        transition: reduced
            ? const []
            : const [
                ElTransition.all(Duration(milliseconds: 150), Curves.ease),
              ],
      ),
      child: component.loading
          ? const ExcludeSemantics(child: MyLoading(size: MyLoadingSize.small))
          : actionContent,
    );
    return myInline(
      MyAction(
        style: component.style ?? const ElStyle(),
        label: component.semanticLabel,
        button: false,
        toggled: current,
        focusNode: component.focusNode,
        event: component.event,
        disabled: component.disabled,
        blocked: component.loading,
        activateOnEnter: false,
        delayTouchUp: Duration.zero,
        onActivate: (_) => $obs.value = !current,
        child: ElView(
          style: ElStyle(
            minWidth: width,
            height: height,
            padding: EdgeInsets.all(gap),
            alignment: .centerLeft,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: current
                ? (component.activeColor ?? theme.primary)
                : (component.inactiveColor ?? theme.gray),
            color: current ? theme.primaryText : theme.textColor,
            transition: reduced
                ? const []
                : const [
                    ElTransition.all(Duration(milliseconds: 230), Curves.ease),
                  ],
          ).merge(component.trackStyle),
          child: Stack(
            children: [
              Row(
                mainAxisSize: .min,
                children: [
                  if (current && content != null)
                    ElView(
                      style: ElStyle(padding: EdgeInsets.only(right: gap)),
                      child: content,
                    ),
                  SizedBox(width: thumb, height: thumb),
                  if (!current && content != null)
                    ElView(
                      style: ElStyle(padding: EdgeInsets.only(left: gap)),
                      child: content,
                    ),
                ],
              ),
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: current ? .centerRight : .centerLeft,
                  duration: reduced || !component.slide
                      ? Duration.zero
                      : const Duration(milliseconds: 230),
                  curve: Curves.ease,
                  child: thumbVisual,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 47×28的开关，使用原生开关的Space与辅助技术语义。
class MySwitch extends StatelessWidget {
  /// 局部开关滑块背景。
  static const $thumbBackground = 'my.switch.thumbBackground';

  /// value或modelValue必须提供其一，label不绘制为可见文字。
  const MySwitch({
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
  Widget build(BuildContext context) => MyValueBuilder<bool>(
    value: value ?? false,
    notifier: modelValue,
    onChanged: onChanged,
    builder: (context, current, change) {
      final t = context.elTheme;
      final transitions = myReducedMotion(context)
          ? <ElTransition>[]
          : const [ElTransition.all(Duration(milliseconds: 230), Curves.ease)];
      return myInline(
        MyAction(
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
                  ElView.maybeOf(context)?.getVar<Color>(MySwitch.$thumbBackground) ??
                  (current ? t.primaryText : const Color(0xffffffff)),
              transform: ElTransform.translate(current ? 19 : 0, 0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff000000).withValues(alpha: .12),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                ),
              ],
              transition: myReducedMotion(context)
                  ? const []
                  : const [
                      ElTransition.field(
                        ElTransitionField.transform,
                        Duration(milliseconds: 230),
                        Curves.ease,
                      ),
                      ElTransition.field(
                        ElTransitionField.backgroundColor,
                        Duration(milliseconds: 150),
                        Curves.ease,
                      ),
                    ],
            ),
          ),
        ),
      );
    },
  );
}

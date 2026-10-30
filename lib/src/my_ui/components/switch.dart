/// 参照：D:/project/html/my-ui/packages/vue/components/Switch.vue；packages/core/my-ui.js:1358-1376；my-ui.css:544-579。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../cores/common.dart';
import '../cores/theme.dart';

/// 47×28的开关，使用原生开关的Space与辅助技术语义。
class MySwitch extends StatelessWidget {
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
      final t = MyTheme.of(context);
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
            bgColor: current ? t.primary : t.gray,
            cursor: disabled
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            transitions: transitions,
            onFocusVisible: myFocusStyle(context),
          ),
          child: ElView(
            style: ElStyle(
              width: 22,
              height: 22,
              borderRadius: BorderRadius.circular(99),
              bgColor:
                  t.switchThumbBackground ??
                  (current ? t.primaryText : const Color(0xffffffff)),
              transform: ElTransform.translate(current ? 19 : 0, 0),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff000000).withValues(alpha: .12),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                ),
              ],
              transitions: myReducedMotion(context)
                  ? const []
                  : const [
                      ElTransition.field(
                        ElTransitionField.transform,
                        Duration(milliseconds: 230),
                        Curves.ease,
                      ),
                      ElTransition.field(
                        ElTransitionField.bgColor,
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

import 'package:flutter_base/src/ui/desktop/internal.dart';
import 'package:flutter/widgets.dart';

/// Element 开关主题实现：只服务 [ElementPlusThemeData]，由 barrel 挡住、不经 `element_plus.dart` 导出。
class Switch extends StatelessWidget {
  const Switch(this.component, this.model, {super.key});

  final ElSwitch component;
  final Obs<bool> model;

  // 官方 switch 使用 transition: all .3s，未指定 timing-function 时为 CSS ease。
  static const _transition = [ElTransition.all(Duration(milliseconds: 300), Curves.ease)];

  @override
  Widget build(BuildContext context) {
    final on = model.value;
    final interactive = !component.disabled && !component.loading;
    final compact = context.elComponentCompact(component.style);
    final height = compact ? 24.0 : 26.0;
    const gap = 2.0;
    final track = on ? context.elTheme.primary : context.elTheme.borderColor;
    void toggle() => model.value = !model.value;

    final thumb = height - 2 * gap;
    // 开关按自身尺寸排布，不被父级紧约束撑满。
    return UnconstrainedBox(
      child: ElView(
        // loading / 禁用期间摘掉节点，不进入焦点链。
        focusNode: interactive ? component.focusNode : null,
        event: component.disabled
            ? (component.event ?? ElEvent()).copyWith(disabled: true)
            : interactive
            ? ElButtonView.buildEvent(toggle, false, component.event)
            : component.event,
        semantics: ElSemantics(
          mergeDescendants: true,
          toggled: on,
          enabled: !component.disabled,
          label: component.semanticLabel,
          onTap: interactive ? toggle : null,
        ),
        style: ElStyle(
          width: height * 1.75,
          height: height,
          padding: const EdgeInsets.all(gap),
          alignment: on ? .centerRight : .centerLeft,
          backgroundColor: track,
          border: ElBorder.all(borderWidth: 1, borderColor: track),
          borderRadius: BorderRadius.circular(height / 2),
          cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          userSelect: .none,
          transition: _transition,
          onFocusVisible: ElStyle(
            outline: ElOutline(outlineWidth: 2, outlineColor: context.elTheme.primary, outlineOffset: 1),
          ),
          // 官方禁用把整体压到 0.6 透明度。
          onDisabled: const ElStyle(opacity: 0.6, cursor: SystemMouseCursors.forbidden),
        ).merge(component.style),
        child: ElView(
          style: ElStyle(
            width: thumb,
            height: thumb,
            alignment: .center,
            backgroundColor: context.elTheme.white,
            borderRadius: BorderRadius.circular(thumb / 2),
            iconColor: track,
            transition: _transition,
          ),
          child: component.loading ? ElLoading(child: ElIcon(ElIcons.loading, size: thumb * 0.7)) : null,
        ),
      ),
    );
  }
}

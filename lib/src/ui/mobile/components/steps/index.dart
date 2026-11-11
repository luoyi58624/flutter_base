import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 移动端步骤条只管理呈现和点击，当前进度由公共模型持有。
Widget stepsBuilder(BuildContext context, ElSteps c) {
  final t = context.elTheme;
  final current = c.currentValue.clamp(0, c.children.length);
  Widget item(int i) {
    final step = c.children[i];
    final done = i < current, active = i == current;
    final error = active && c.status == .error;
    final color = error
        ? t.error
        : done || active
        ? t.primary
        : t.textSecondary;
    final marker = ElView(
      style: ElStyle(
        width: 30,
        height: 30,
        alignment: .center,
        borderRadius: .circular(15),
        color: done || active ? t.primaryText : color,
        fontSize: 13,
        iconSize: 15,
        iconColor: done || active ? t.primaryText : color,
        backgroundColor: done || active ? color : t.fill,
      ),
      child:
          step.icon ??
          (done
              ? ElMobileIcons.check
              : error
              ? ElMobileIcons.x
              : '${i + 1}'),
    );
    final copy = Column(
      mainAxisSize: .min,
      crossAxisAlignment: c.vertical ? .start : .center,
      spacing: 6,
      children: [
        ElView(
          style: ElStyle(
            fontSize: 13,
            fontWeight: active ? .w600 : .w400,
            color: color,
            textAlign: c.vertical ? .start : .center,
          ),
          child: step.title,
        ),
        if (step.description != null)
          ElView(
            style: ElStyle(
              fontSize: 12,
              lineHeight: 1.7,
              color: t.textSecondary,
              textAlign: c.vertical ? .start : .center,
            ),
            child: step.description,
          ),
      ],
    );
    final content = c.vertical
        ? Row(
            crossAxisAlignment: .start,
            children: [
              marker,
              const SizedBox(width: 14),
              Expanded(child: copy),
            ],
          )
        : Column(mainAxisSize: .min, spacing: 10, children: [marker, copy]);
    return ActionView(
      disabled: !c.interactive || c.disabled || step.disabled,
      selected: active,
      label: step.title is String ? step.title as String : null,
      onActivate: (_) => c.currentValue = i,
      style: ElStyle(padding: c.vertical ? const .only(bottom: 24) : const .symmetric(horizontal: 4)).merge(step.style),
      child: content,
    );
  }

  return ElView(
    style: c.style,
    semantics: ElSemantics(container: true, label: c.semanticLabel),
    child: c.vertical
        ? Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [for (var i = 0; i < c.children.length; i++) item(i)],
          )
        : Row(
            crossAxisAlignment: .start,
            children: [for (var i = 0; i < c.children.length; i++) Expanded(child: item(i))],
          ),
  );
}

/// 独立步骤成员沿用相同文字层级。
Widget stepBuilder(BuildContext context, ElStep c) => ElView(
  style: c.style,
  child: Column(
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    spacing: 6,
    children: [buildContent(c.title), if (c.description != null) buildContent(c.description)],
  ),
);

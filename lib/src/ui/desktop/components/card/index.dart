import 'package:flutter/widgets.dart';

import '../../../../flutter/components/tokens.dart' show ElLevelTypeExt;
import '../../../../flutter/components/card/index.dart' show ElCard;
import '../../../../flutter/components/loading_indicator/index.dart' show ElLoadingIndicator;
import '../../../../flutter/views/button/button_view.dart' show ElButtonView;
import '../../../../flutter/views/view/semantics/semantics.dart' show ElSemantics;
import '../../../../flutter/views/view/style/style.dart' show ElStyle;
import '../../../../flutter/views/view/view.dart' show ElView;

/// 桌面端卡片只提供区域语义、阴影档位与加载态，外观完全由用户 style 决定。
Widget cardBuilder(BuildContext context, ElCard component) {
  final style = ElStyle(boxShadow: component.shadowLevel?.shadow(context)).merge(component.style);
  final content = Stack(
    alignment: .center,
    children: [
      IgnorePointer(
        ignoring: component.loading,
        child: Opacity(opacity: component.loading ? .4 : 1, child: component.child ?? const SizedBox.shrink()),
      ),
      if (component.loading) const ElLoadingIndicator(),
    ],
  );
  return ElView(
    semantics: ElSemantics(container: true, explicitChildNodes: true, label: component.semanticLabel),
    child: component.onTap == null && component.event?.onTap == null
        ? ElView(style: style, event: component.event, child: content)
        : ElButtonView(
            style: style,
            event: component.event,
            onPressed: component.onTap,
            disabled: component.loading,
            child: content,
          ),
  );
}

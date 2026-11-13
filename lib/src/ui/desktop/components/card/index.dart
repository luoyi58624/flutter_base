import 'package:flutter/widgets.dart';

import '../../../../flutter/components/card/index.dart' show ElCard;
import '../../../../flutter/components/loading_indicator/index.dart' show ElLoadingIndicator;
import '../../../../flutter/views/button/button_view.dart' show ElButtonView;
import '../../../../flutter/views/view/semantics/semantics.dart' show ElSemantics;
import '../../../../flutter/views/view/view.dart' show ElView;

/// 桌面端卡片提供区域语义与加载态，并应用调用方声明的样式。
Widget cardBuilder(BuildContext context, ElCard component) {
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
        ? ElView(style: component.style, event: component.event, child: content)
        : ElButtonView(
            style: component.style,
            event: component.event,
            onPressed: component.onTap,
            disabled: component.loading,
            child: content,
          ),
  );
}

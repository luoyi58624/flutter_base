import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 移动端头像在图片失败时保留文字或调用方内容。
Widget avatarBuilder(BuildContext context, ElAvatar c) {
  final t = context.elTheme;
  final fallback = c.child ?? (c.alt.isEmpty ? ElMobileIcons.user : c.alt.characters.take(2).toString());
  final content = ElView(
    style: ElStyle(alignment: .center, color: t.primary, fontSize: c.size * .36, iconSize: c.size * .5),
    child: buildContent(fallback),
  );
  return ElView(
    semantics: ElSemantics(image: true, label: c.semanticLabel ?? c.alt),
    style: ElStyle(
      width: c.size,
      height: c.size,
      alignment: .center,
      clipBehavior: .antiAlias,
      backgroundColor: Color.alphaBlend(t.primary.withValues(alpha: .10), t.cardColor),
      borderRadius: .circular(c.shape == .circle ? c.size / 2 : c.size * .28),
    ).merge(c.style),
    child: c.src == null || c.src!.isEmpty
        ? content
        : ElImage(
            c.src!,
            fit: .cover,
            width: c.size,
            height: c.size,
            placeholder: content,
            error: content,
            onLoad: c.onLoad,
            onError: c.onError,
          ),
  );
}

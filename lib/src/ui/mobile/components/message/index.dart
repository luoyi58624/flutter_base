import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 移动消息是类型色通栏，底色延伸到状态栏后方，内容让出状态栏高度；从顶部向下滑入，退场反向滑出。
/// 不显示关闭按钮，点击通栏即关闭，常驻消息也能收起。
Widget messageBuilder(BuildContext context, ElMessage c) => ElOverlayTransition(
  duration: const Duration(milliseconds: 250),
  builder: (context, animation) => SlideTransition(
    position: animation.drive(
      Tween(begin: const Offset(0, -1), end: Offset.zero).chain(CurveTween(curve: const Cubic(0, 0, .2, 1))),
    ),
    child: ElView(
      event: c.onClose == null ? null : ElEvent(onTap: (_) => c.onClose!()),
      style: ElStyle(
        width: '100%',
        padding: .fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 12),
        backgroundColor: c.type.color(context),
        color: const Color(0xffffffff),
        iconColor: const Color(0xffffffff),
        iconSize: 20,
        fontSize: 15,
        fontWeight: .w500,
      ).merge(c.style),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          spacing: 10,
          children: [
            switch (c.type) {
              .success => ElMobileIcons.check,
              .warning => ElMobileIcons.alertTriangle,
              .error => ElMobileIcons.alertCircle,
              _ => ElMobileIcons.info,
            },
            Expanded(child: buildContent(c.child)),
          ],
        ),
      ),
    ),
  ),
);

/// 移动消息固定在顶部，新消息叠在旧消息上方。
Widget messageStackBuilder(BuildContext context, List<Widget> children) => Align(
  alignment: .topCenter,
  child: Stack(children: children),
);

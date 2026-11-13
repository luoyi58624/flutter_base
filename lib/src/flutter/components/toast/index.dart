import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../dart.dart' show El, el;
import '../../extensions/index.dart' show ElNavigatorExt;
import '../../views/view/style/style.dart';
import '../../widgets/popup/transition.dart' show OverlayTransitions;
import '../index.dart';

part 'service.dart';

/// 非阻塞的短提示内容，可直接嵌入页面，也可经 el.toast 显示在根 Overlay。
class ElToast extends StatelessWidget {
  /// 外观与进退场动画由品牌实现。
  const ElToast({super.key, required this.child, this.style});

  /// 提示内容，可传文字或 Widget。
  final Object child;

  /// 在品牌默认样式后合并。
  final ElStyle? style;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.toast)(context, this);
}

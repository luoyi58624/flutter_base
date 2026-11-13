import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../dart.dart' show El, el;
import '../../commons/models.dart' show ElThemeType;
import '../../extensions/index.dart' show ElNavigatorExt;
import '../../views/view/style/style.dart';
import '../../widgets/popup/transition.dart' show OverlayTransitions;
import '../index.dart';

part 'service.dart';

/// 单条消息的内容声明，可直接嵌入页面，也可经 el.message 显示在根 Overlay 顶部。
class ElMessage extends StatelessWidget {
  /// 外观与进退场动画由品牌实现，多条消息的排布见 [ElComponents.messageStack]。
  const ElMessage({super.key, required this.child, this.type = .info, this.style, this.onClose});

  /// 消息内容，可传文字或 Widget。
  final Object child;

  /// 语义类型，品牌据此决定颜色和图标。
  final ElThemeType type;

  /// 在品牌默认样式后合并。
  final ElStyle? style;

  /// 关闭入口的回调，为空时品牌不提供关闭入口。
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.message)(context, this);
}

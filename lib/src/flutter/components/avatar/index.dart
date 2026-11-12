import 'package:flutter/widgets.dart';

import '../../views/image/index.dart' show ImageLoadInfo;
import '../../views/view/style/style.dart' show ElStyle;
import '../index.dart' show ElComponentProvider;

/// 头像的几何形状。
enum ElAvatarShape {
  /// 圆形头像。
  circle,

  /// 圆角方形头像。
  square,
}

/// 图片、回退内容和加载通知的头像声明。
class ElAvatar extends StatelessWidget {
  /// 创建与 Web 相同的头像内容，交互由外层视图组合。
  const ElAvatar({
    super.key,
    this.src,
    this.alt = '',
    this.size = 40,
    this.shape = .circle,
    this.onLoad,
    this.onError,
    this.style,
    this.semanticLabel,
    this.child,
  }) : assert(size >= 0 && size < double.infinity, 'size 必须是非负有限数');

  /// 头像图片地址，缺失或失败时展示回退内容。
  final String? src;

  /// 图片辅助名称，也是默认缩写文字的来源。
  final String alt;

  /// 头像的逻辑边长。
  final double size;

  /// 圆形或圆角方形。
  final ElAvatarShape shape;

  /// 当前图片加载完成后的原始尺寸信息。
  final ValueChanged<ImageLoadInfo>? onLoad;

  /// 当前图片加载失败并切换到回退内容时通知。
  final ValueChanged<Object>? onError;

  /// 在品牌默认外观之后合并的根样式。
  final ElStyle? style;

  /// 显式辅助名称，省略时由品牌使用 alt 或回退文字。
  final String? semanticLabel;

  /// 明确指定的回退文字或 Widget，优先于 alt 的自动缩写。
  final Object? child;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.avatar)(context, this);
}

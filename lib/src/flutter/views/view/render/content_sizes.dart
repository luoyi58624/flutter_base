import 'package:flutter/foundation.dart';

/// 内容尺寸：min-content / max-content（单位 px）。
@immutable
class ContentSizes {
  /// 创建。
  const ContentSizes(this.minContent, this.maxContent);

  /// 全零。
  static const ContentSizes zero = ContentSizes(0, 0);

  /// 最窄不溢出尺寸（px）。
  final double minContent;

  /// 完全不换行尺寸（px）。
  final double maxContent;
}

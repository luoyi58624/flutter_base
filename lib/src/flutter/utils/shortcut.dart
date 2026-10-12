import 'package:flutter/services.dart';

import 'platform/index.dart';

/// 提供随操作系统适配的快捷键修饰键。
class ElShortcutUtil {
  ElShortcutUtil._();

  /// 定义 ctrl 修饰键，但在 Mac 操作系统上，ctrl 修饰键相当于 command 键
  static final ctrl = !ElPlatform.isMacOS
      ? LogicalKeyboardKey.control
      : LogicalKeyboardKey.meta;
}

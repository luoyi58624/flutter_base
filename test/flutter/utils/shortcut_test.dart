import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('快捷键修饰键适配本机平台', () {
    expect(
      ElShortcutUtil.ctrl,
      Platform.isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
    );
  });
}

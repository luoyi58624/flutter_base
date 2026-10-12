import 'dart:io';

import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('平台判定使用本机和测试环境信息', () {
    expect(ElPlatform.isWindows, Platform.isWindows);
    expect(ElPlatform.isMacOS, Platform.isMacOS);
    expect(ElPlatform.isDesktopClient, ElPlatform.isDesktop);
    expect(ElPlatform.isFlutterTest, isTrue);
    expect(ElPlatform.isMobileWeb, isFalse);
  });
}

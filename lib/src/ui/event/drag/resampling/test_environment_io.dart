import 'dart:io' show Platform;

/// Flutter 测试运行器通过进程环境显式声明测试模式。
bool get isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

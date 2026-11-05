/// 在非 Web 平台让出一次 Dart 事件循环，供条件门面与纯 Dart 测试使用。
Future<void> yieldLongLineWebEventLoop() => Future<void>.delayed(Duration.zero);

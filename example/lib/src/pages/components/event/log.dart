import 'package:flutter/foundation.dart';

/// 将事件名称和可选的数据打印到调试控制台。
void printEvent(String name, [Object? data]) {
  debugPrint(data == null ? name : '$name $data');
}

import 'package:flutter/widgets.dart';

/// 在组件实例上保存跨构建使用的内部对象。
mixin ElWidgetMixin on Widget {
  final Map<Object, dynamic> _map = {};

  @protected
  T $set<T>(Object key, T value) {
    return _map[key] = value;
  }

  @protected
  T $get<T>(Object key) {
    assert(_map.containsKey(key), 'No key = $key was found.');
    return _map[key] as T;
  }
}

import 'package:flutter/foundation.dart';

/// 级联继承的变量表；合并、共享与同值稳定化沿用旧样式系统。
@immutable
class InheritedVars {
  /// 创建变量表，调用方保证传入后不再修改。
  const InheritedVars([this.map = const {}]);

  /// 根节点与无声明子树共享的空表。
  static const InheritedVars empty = InheritedVars();

  /// 已合并的有效变量，不解析键名或变量值。
  final Map<Object, Object> map;

  /// 合并当前层声明，无声明或所有键值已存在时直接借用当前表。
  InheritedVars merge(Map<Object, Object>? local) {
    if (local == null || local.isEmpty) return this;
    if (_subsumes(map, local)) return this;
    return InheritedVars(map.isEmpty ? local : {...map, ...local});
  }

  static bool _subsumes(Map<Object, Object> base, Map<Object, Object> local) {
    for (final entry in local.entries) {
      if (base[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// 重新合并后若值不变，保留旧实例以截断后代传播。
  InheritedVars stabilize(InheritedVars previous) {
    if (identical(this, previous)) return previous;
    return this == previous ? previous : this;
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is InheritedVars && mapEquals(map, other.map);

  @override
  int get hashCode =>
      _varsHashCache[this] ??= Object.hash(Object.hashAllUnordered(map.keys), Object.hashAllUnordered(map.values));
}

final Expando<int> _varsHashCache = Expando<int>('elInheritedVarsHash');

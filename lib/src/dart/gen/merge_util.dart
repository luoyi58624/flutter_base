part of 'index.dart';

/// el_gen 集合合并运行时支撑(生成代码专用,业务代码不要直接引用)。
/// Map 逐 key 并集合并(CSS custom properties 口径):后表同名 key 覆前表。
///
/// 空表短路直接返回另一侧原实例,保 identical 稳定(合并无效果不击穿下游
/// identity 门)。
Map<K, V> $elMergeMap<K, V>(Map<K, V> base, Map<K, V> other) {
  if (other.isEmpty) return base;
  if (base.isEmpty) return other;
  return {...base, ...other};
}

/// Map key 并集 + 同 key 值深合并(value 可 merge 时的口径,如变体样式表):
/// 两侧同 key 时 value 走 [merge] 回调,单侧 key 直取。
///
/// 注意:V 为可空类型时,base 侧的 null 值按"缺失"处理(直取 other 侧)。
Map<K, V> $elMergeMapDeep<K, V>(
  Map<K, V> base,
  Map<K, V> other,
  V Function(V a, V b) merge,
) {
  if (other.isEmpty) return base;
  if (base.isEmpty) return other;
  final result = Map<K, V>.of(base);
  for (final entry in other.entries) {
    final existing = base[entry.key];
    result[entry.key] = existing == null
        ? entry.value
        : merge(existing, entry.value);
  }
  return result;
}

part of 'table.dart';

const _tableCacheSchema = 1;
const _tableStorageName = 'el_ui_tables';
const _tableStoragePrefix = 'table.v1.';

abstract final class _TableCacheBackend {
  static final Map<String, Object?> _memory = <String, Object?>{};
  static final ElStorageGroup _group = ElStorageGroup(key: 'el_ui_table');
  static ElStorage? _storage;
  static Future<ElStorage?>? _openingStorage;

  static ElStorage? _currentStorage() {
    final current = _storage;
    return current == null || current.isClose ? null : current;
  }

  static Future<ElStorage?> ensureStorage() {
    final current = _currentStorage();
    if (current != null) return Future<ElStorage?>.value(current);

    final opening = _openingStorage;
    if (opening != null) return opening;

    return _openingStorage = _openStorage();
  }

  static Future<ElStorage?> _openStorage() async {
    try {
      return _storage = await _group.open(_tableStorageName);
    } catch (_) {
      // 存储不可用时，内存镜像仍保持完整缓存合同。
      return null;
    } finally {
      _openingStorage = null;
    }
  }

  static Object? read(String key) {
    try {
      final persisted = _currentStorage()?.getItem<Object?>(key);
      if (persisted != null) _memory[key] = persisted;
    } catch (_) {
      // 存储损坏或未就绪时只忽略持久化层，不影响表格运行态。
    }
    return _memory[key];
  }

  static void write(String key, Object value) {
    _memory[key] = value;
    try {
      final storage = _currentStorage();
      if (storage == null) {
        unawaited(ensureStorage().then((storage) => storage?.setItem<Object?>(key, value)));
      } else {
        storage.setItem<Object?>(key, value);
      }
    } catch (_) {
      // 后续配置变化会再次尝试落盘，当前进程内恢复能力不受影响。
    }
  }

  static void remove(String key) {
    _memory.remove(key);
    try {
      final storage = _currentStorage();
      if (storage == null) {
        unawaited(ensureStorage().then((storage) => storage?.removeItem(key)));
      } else {
        storage.removeItem(key);
      }
    } catch (_) {
      // remove 对内存镜像已生效，未初始化存储时保持幂等。
    }
  }
}

@immutable
class _TableCachedState {
  const _TableCachedState({
    required this.order,
    required this.visibility,
    required this.widths,
    this.fixed = const {},
    this.sortKey,
    this.sortAscending,
  });

  final List<String> order;
  final Map<String, bool> visibility;
  final Map<String, double> widths;

  /// 已固定列的固定方向快照：列 token → `left` / `right`；未固定的列不出现。
  final Map<String, ElTableColumnFixed> fixed;
  final String? sortKey;
  final bool? sortAscending;

  Map<String, Object?> toMap() => <String, Object?>{
    'schema': _tableCacheSchema,
    'order': order,
    'visibility': visibility,
    'widths': widths,
    'fixed': <String, String>{for (final entry in fixed.entries) entry.key: _tableFixedToken(entry.value)},
    'sortKey': sortKey,
    'sortAscending': sortAscending,
  };

  static _TableCachedState? tryParse(Object? raw) {
    if (raw is! Map || raw['schema'] != _tableCacheSchema) return null;
    final orderRaw = raw['order'];
    final visibilityRaw = raw['visibility'];
    final widthsRaw = raw['widths'];
    if (orderRaw is! List || visibilityRaw is! Map || widthsRaw is! Map) return null;
    final order = <String>[];
    for (final value in orderRaw) {
      if (value is String && !order.contains(value)) order.add(value);
    }
    final visibility = <String, bool>{};
    visibilityRaw.forEach((key, value) {
      if (key is String && value is bool) visibility[key] = value;
    });
    final widths = <String, double>{};
    widthsRaw.forEach((key, value) {
      if (key is String && value is num && value.isFinite && value > 0) {
        widths[key] = value.toDouble();
      }
    });
    // 版本兼容：旧负载没有 fixed 字段时按「全部未固定」处理，不能因为缺字段就当缓存损坏；
    // 字段存在但内容不合法时同样只忽略这一条，不影响顺序 / 显隐 / 列宽的恢复。
    final fixed = <String, ElTableColumnFixed>{};
    final fixedRaw = raw['fixed'];
    if (fixedRaw is Map) {
      fixedRaw.forEach((key, value) {
        final direction = _tableFixedFromToken(value);
        if (key is String && direction != null) fixed[key] = direction;
      });
    }
    final sortKey = raw['sortKey'];
    final sortAscending = raw['sortAscending'];
    return _TableCachedState(
      order: List<String>.unmodifiable(order),
      visibility: Map<String, bool>.unmodifiable(visibility),
      widths: Map<String, double>.unmodifiable(widths),
      fixed: Map<String, ElTableColumnFixed>.unmodifiable(fixed),
      sortKey: sortKey is String ? sortKey : null,
      sortAscending: sortAscending is bool ? sortAscending : null,
    );
  }
}

/// 固定方向的缓存取值（枚举名），与解析端 [_tableFixedFromToken] 成对。
String _tableFixedToken(ElTableColumnFixed value) => value.name;

/// 缓存取值 → 固定方向；不认识的值返回 null（该列按未固定处理）。
ElTableColumnFixed? _tableFixedFromToken(Object? value) =>
    value is String ? ElTableColumnFixed.values.asNameMap()[value] : null;

String? _tableColumnToken(ElTableColumn column) {
  final key = column.key;
  if (key != null) return _tableValueToken('key', key);
  final field = column.prop;
  if (field != null && field.isNotEmpty) return 'field:$field';
  final title = column.title;
  return title == null ? null : _tableValueToken('title', title);
}

String? _tableValueToken(String kind, Object value) => switch (value) {
  String value => '$kind:s:$value',
  int value => '$kind:i:$value',
  double value when value.isFinite => '$kind:d:$value',
  bool value => '$kind:b:${value ? 1 : 0}',
  _ => null,
};

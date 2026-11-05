part of 'index.dart';

/// 按视图类型存放可重新绑定的条目，并记录各类型的准备成本。
class RecycledViewPool {
  final Map<int, _ScrapData> _scrap = {};

  /// 释放池中的所有条目，保留类型容量和已经测得的准备成本。
  void clear() {
    final holders = _holders.toList(growable: false);
    for (final data in _scrap.values) {
      data.holders.clear();
    }
    for (final holder in holders) {
      holder._owner?._discardHolder(holder);
    }
  }

  /// 设置指定类型最多保留的条目数量，并释放超出的条目。
  void setMaxRecycledViews(int viewType, int max) {
    if (max < 0) {
      throw ArgumentError.value(max, 'max', '回收池容量不能为负数。');
    }
    final data = _dataForType(viewType)..maxScrap = max;
    while (data.holders.length > max) {
      final holder = data.holders.removeLast();
      holder._owner?._discardHolder(holder);
    }
  }

  /// 返回池中指定视图类型的条目数量。
  int getRecycledViewCount(int viewType) => _dataForType(viewType).holders.length;

  /// 取出最近回收的指定类型条目，没有可用条目时返回 null。
  ViewHolder? getRecycledView(int viewType) {
    final data = _scrap[viewType];
    return data == null || data.holders.isEmpty ? null : data.holders.removeLast();
  }

  /// 清除条目的旧绑定身份并加入类型池，容量已满时释放条目。
  void putRecycledView(ViewHolder scrap) {
    if (_contains(scrap)) {
      throw StateError('同一个 ViewHolder 不能重复加入回收池。');
    }
    final data = _dataForType(scrap.getItemViewType());
    if (data.holders.length >= data.maxScrap) {
      scrap._owner?._discardHolder(scrap);
      return;
    }
    scrap._resetInternal();
    data.holders.add(scrap);
  }

  Iterable<ViewHolder> get _holders => _scrap.values.expand((data) => data.holders);

  bool _contains(ViewHolder holder) => _scrap.values.any((data) => data.holders.contains(holder));

  bool _remove(ViewHolder holder) {
    for (final data in _scrap.values) {
      if (data.holders.remove(holder)) return true;
    }
    return false;
  }

  _ScrapData _dataForType(int viewType) => _scrap.putIfAbsent(viewType, _ScrapData.new);

  void _factorInCreateTime(int viewType, int createTimeUs) {
    final data = _dataForType(viewType);
    data.createRunningAverageUs = _runningAverage(data.createRunningAverageUs, createTimeUs);
  }

  void _factorInBindTime(int viewType, int bindTimeUs) {
    final data = _dataForType(viewType);
    data.bindRunningAverageUs = _runningAverage(data.bindRunningAverageUs, bindTimeUs);
  }

  bool _willCreateInTime(int viewType, int approxCurrentUs, int deadlineUs) {
    final expectedDurationUs = _dataForType(viewType).createRunningAverageUs;
    return expectedDurationUs == 0 || approxCurrentUs + expectedDurationUs < deadlineUs;
  }

  bool _willBindInTime(int viewType, int approxCurrentUs, int deadlineUs) {
    final expectedDurationUs = _dataForType(viewType).bindRunningAverageUs;
    return expectedDurationUs == 0 || approxCurrentUs + expectedDurationUs < deadlineUs;
  }

  int _runningAverage(int oldAverage, int newValue) =>
      oldAverage == 0 ? newValue : (oldAverage ~/ 4 * 3) + (newValue ~/ 4);
}

class _ScrapData {
  final List<ViewHolder> holders = [];
  int maxScrap = 5;
  int createRunningAverageUs = 0;
  int bindRunningAverageUs = 0;
}

part of 'box_selection_view.dart';

typedef _BoxSelectionChange = ({Set<Object> added, Set<Object> removed, int selectedCount});

/// 框选宿主内部协议，与字符参与者和复制载荷无关。
abstract interface class _BoxSelectionDelegate {
  /// 当前已挂载、可以全选的真实对象值。
  Iterable<Object> get selectableValues;

  /// 同步实际变化项的样式。
  void selectionChanged(_BoxSelectionChange change);

  /// 在允许业务重建的阶段发布变化。
  void selectionPublished(_BoxSelectionChange change);
}

/// 实验性对象框选控制器；稳定值跨虚拟卸载保留，由业务清空或取消选择。
///
/// 仅用于试验验证，不适用于生产环境。
class ElBoxSelectionController extends ChangeNotifier {
  /// 创建独立保存稳定对象值的空框选控制器。
  ElBoxSelectionController();

  final Set<Object> _selected = <Object>{};
  late final Set<Object> _view = UnmodifiableSetView(_selected);
  _BoxSelectionDelegate? _delegate;
  Set<Object>? _pendingAdded;
  Set<Object>? _pendingRemoved;
  bool _disposed = false;

  /// 当前只读集合视图；需要历史快照时由调用方显式复制。
  Set<Object> get selectedValues => _view;

  /// 当前选中数量。
  int get selectedCount => _selected.length;

  /// 对象是否选中。
  bool isSelected(Object value) => _selected.contains(value);

  /// 加选一个对象；重复选择不通知。
  void select(Object value) => _applyChanges(added: <Object>[value]);

  /// 取消一个对象；未选中时不通知。
  void deselect(Object value) => _applyChanges(removed: <Object>[value]);

  /// 清空全部选中值，包括已卸载的虚拟对象。
  void clear() => _applyChanges(removed: _selected.toList(growable: false));

  /// 普通布局全选真实对象，虚拟布局仅加选当前可见项，不构建离屏内容。
  void selectAll() => _applyChanges(added: _delegate?.selectableValues ?? const <Object>[]);

  // 批量应用差集，只通知实际改变的对象。
  void _applyChanges({Iterable<Object> added = const [], Iterable<Object> removed = const []}) {
    final additions = <Object>{};
    final removals = <Object>{};
    for (final value in removed) {
      if (_selected.remove(value)) removals.add(value);
    }
    for (final value in added) {
      if (_selected.add(value) && !removals.remove(value)) additions.add(value);
    }
    if (additions.isEmpty && removals.isEmpty) return;
    final change = (
      added: Set<Object>.unmodifiable(additions),
      removed: Set<Object>.unmodifiable(removals),
      selectedCount: _selected.length,
    );
    _delegate?.selectionChanged(change);
    if ((_delegate == null || SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) &&
        _pendingAdded == null) {
      _publish(change);
      return;
    }
    if (_pendingAdded == null) {
      _pendingAdded = <Object>{};
      _pendingRemoved = <Object>{};
      scheduleMicrotask(() {
        final added = _pendingAdded!;
        final removed = _pendingRemoved!;
        _pendingAdded = _pendingRemoved = null;
        if (!_disposed && (added.isNotEmpty || removed.isNotEmpty)) {
          _publish((
            added: Set<Object>.unmodifiable(added),
            removed: Set<Object>.unmodifiable(removed),
            selectedCount: _selected.length,
          ));
        }
      });
    }
    for (final value in removals) {
      if (!_pendingAdded!.remove(value)) _pendingRemoved!.add(value);
    }
    for (final value in additions) {
      if (!_pendingRemoved!.remove(value)) _pendingAdded!.add(value);
    }
  }

  void _publish(_BoxSelectionChange change) {
    _delegate?.selectionPublished(change);
    if (!_disposed) notifyListeners();
  }

  // 一个控制器只绑定一个框选根，避免手势互相覆盖。
  void _bind(_BoxSelectionDelegate delegate) {
    if (_delegate != null && !identical(delegate, _delegate)) {
      throw StateError('ElBoxSelectionController 只能绑定一个 ElBoxSelectionView。');
    }
    _delegate = delegate;
  }

  // 离树后保留业务持有的稳定值集合。
  void _unbind(_BoxSelectionDelegate delegate) {
    if (identical(delegate, _delegate)) _delegate = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _delegate = null;
    super.dispose();
  }
}

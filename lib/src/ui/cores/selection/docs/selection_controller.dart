part of 'selection_view.dart';

/// 文档选区控制器，仅提供选中文本与基本操作。
class ElSelectionController extends ChangeNotifier {
  /// 创建独立文档选区控制器。
  ElSelectionController();

  SelectionControllerDelegate? _delegate;
  String? _text;
  bool _resolving = false;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// 当前选中文本；无选区时为 null，图片优先使用替代文本、其次源地址。
  String? get text {
    if (_disposed) return _text;
    final delegate = _delegate;
    if (delegate != null) {
      _resolving = true;
      try {
        _updateSelection(delegate.resolveSelectionInfo());
      } finally {
        _resolving = false;
      }
    }
    return _text;
  }

  /// 是否有选区，包括替代文本为空的图片。
  bool get hasSelection => text != null;

  /// 全选当前组件内已挂载的文本与图片。
  void selectAll() => _delegate?.selectAllSelection();

  /// 清空当前选区。
  void clear() => _delegate?.clearSelection();

  /// 复制选区的纯文本表示。
  Future<void> copy() => _delegate?.copySelection() ?? Future<void>.value();

  bool get _hasObservers => hasListeners;

  void _bindDelegate(SelectionControllerDelegate delegate) {
    if (identical(_delegate, delegate)) return;
    if (_delegate != null) throw StateError('一个 ElSelectionController 只能绑定一个文档选区。');
    _delegate = delegate;
    _updateSelection(delegate.selectionInfo);
  }

  void _unbindDelegate(SelectionControllerDelegate delegate) {
    if (!identical(_delegate, delegate)) return;
    _delegate = null;
    _updateSelection(null);
  }

  void _updateSelection(String? value) {
    if (_text == value) return;
    _text = value;
    if (_disposed) return;
    if (!_resolving) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _delegate = null;
    super.dispose();
  }
}

/// 文档视图与控制器之间的内部协议。
abstract interface class SelectionControllerDelegate {
  String? get selectionInfo;
  String? resolveSelectionInfo();
  void selectAllSelection();
  void clearSelection();
  Future<void> copySelection();
}

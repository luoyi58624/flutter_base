part of 'index.dart';

/// 直接保存布局与绘制字段的命令式 View，子 View 默认垂直排列。
class ElView {
  /// 将初始样式映射到自身字段，不保留样式对象或创建 RenderObject。
  ElView({ElStyle style = const ElStyle()})
    : _bgColor = style.bgColor,
      _width = style.width,
      _height = style.height,
      _margin = style.margin,
      _padding = style.padding {
    assert(_validInsets(_margin) && _validInsets(_padding), 'margin 和 padding 必须非负且有限。');
  }

  Color? _bgColor;
  double? _width;
  double? _height;
  EdgeInsets _margin;
  EdgeInsets _padding;
  ElView? _parent;
  List<ElView>? _children;
  void Function()? _requestLayout;
  void Function()? _requestPaint;
  bool _needsLayout = true;
  BoxConstraints? _constraints;
  Size _size = Size.zero;
  Size _outerSize = Size.zero;
  Offset _offset = Offset.zero;
  Rect _paintBounds = Rect.zero;

  /// 背景色，修改后只请求重绘。
  Color? get bgColor => _bgColor;
  set bgColor(Color? value) {
    if (_bgColor == value) return;
    _bgColor = value;
    var root = this;
    while (root._parent != null) {
      root = root._parent!;
    }
    root._requestPaint?.call();
  }

  /// 盒子宽度，修改后请求重新布局，空值恢复自动宽度。
  double? get width => _width;
  set width(double? value) {
    assert(value == null || (value >= 0 && value.isFinite), 'width 必须非负且有限。');
    if (_width == value) return;
    _width = value;
    _markNeedsLayout();
  }

  /// 盒子高度，修改后请求重新布局，空值恢复内容高度。
  double? get height => _height;
  set height(double? value) {
    assert(value == null || (value >= 0 && value.isFinite), 'height 必须非负且有限。');
    if (_height == value) return;
    _height = value;
    _markNeedsLayout();
  }

  /// 盒子外部边距，修改后请求重新布局。
  EdgeInsets get margin => _margin;
  set margin(EdgeInsets value) {
    assert(_validInsets(value), 'margin 必须非负且有限。');
    if (_margin == value) return;
    _margin = value;
    _markNeedsLayout();
  }

  /// 背景内部边距，修改后请求重新布局。
  EdgeInsets get padding => _padding;
  set padding(EdgeInsets value) {
    assert(_validInsets(value), 'padding 必须非负且有限。');
    if (_padding == value) return;
    _padding = value;
    _markNeedsLayout();
  }

  /// 当前父 View，根节点与未添加的 View 返回空值。
  ElView? get parent => _parent;

  /// 当前子 View 的只读快照。
  List<ElView> get children => List.unmodifiable(_children ?? const <ElView>[]);

  /// 当前子 View 数量。
  int get childCount => _children?.length ?? 0;

  /// 最近一次布局的盒子尺寸，包含 padding，不包含 margin。
  Size get size => _size;

  /// 最近一次布局相对父盒子的偏移，包含自身 margin，根节点相对宿主。
  Offset get offset => _parent == null ? _margin.topLeft : _offset;

  /// 将未挂载的 View 添加到末尾，同一个实例只能有一个父节点或宿主。
  void add(ElView child) {
    if (child._parent != null || child._requestLayout != null) {
      throw StateError('View 已有父节点或根宿主，请先解除原来的挂载。');
    }
    for (ElView? ancestor = this; ancestor != null; ancestor = ancestor._parent) {
      if (identical(ancestor, child)) throw ArgumentError('不能将自身或祖先添加为子 View。');
    }
    (_children ??= []).add(child);
    child._parent = this;
    _markNeedsLayout();
  }

  /// 摘下指定子 View，保留实例以便再次添加，返回是否成功。
  bool remove(ElView child) {
    if (!identical(child._parent, this)) return false;
    _children!.remove(child);
    child._parent = null;
    _markNeedsLayout();
    return true;
  }

  void _markNeedsLayout() {
    if (_needsLayout) return;
    _needsLayout = true;
    if (_parent case final parent?) {
      parent._markNeedsLayout();
    } else {
      _requestLayout?.call();
    }
  }

  Size _layout(BoxConstraints outerConstraints, {bool dry = false}) {
    if (!_needsLayout && _constraints == outerConstraints) return _outerSize;
    final constraints = outerConstraints.deflate(_margin);
    var contentWidth = 0.0;
    var y = _padding.top;
    final children = _children;
    if (children != null && children.isNotEmpty) {
      final availableWidth = _width == null ? constraints.maxWidth : constraints.constrainWidth(_width!);
      final childConstraints = BoxConstraints(maxWidth: math.max(0, availableWidth - _padding.horizontal));
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        final childSize = child._layout(childConstraints, dry: dry);
        if (!dry) child._offset = Offset(_padding.left + child._margin.left, y + child._margin.top);
        contentWidth = math.max(contentWidth, childSize.width);
        y += childSize.height;
      }
    }
    final size = constraints.constrain(
      Size(
        _width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : contentWidth + _padding.horizontal),
        _height ?? y + _padding.bottom,
      ),
    );
    final outerSize = outerConstraints.constrain(Size(size.width + _margin.horizontal, size.height + _margin.vertical));
    if (!dry) {
      _constraints = outerConstraints;
      _size = size;
      _outerSize = outerSize;
      _needsLayout = false;
    }
    return outerSize;
  }

  // 位置和矩形只在布局阶段计算，重绘时直接提交缓存的 Rect。
  void _position(Offset origin) {
    _paintBounds = origin & _size;
    final children = _children;
    if (children == null) return;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      child._position(origin + child._offset);
    }
  }

  void _paint(Canvas canvas) {
    final color = _bgColor;
    if (color != null) canvas.drawRect(_paintBounds, _fillPaint..color = color);
    final children = _children;
    if (children == null) return;
    for (var i = 0; i < children.length; i++) {
      children[i]._paint(canvas);
    }
  }
}

bool _validInsets(EdgeInsets value) =>
    value.isNonNegative && value.left.isFinite && value.top.isFinite && value.right.isFinite && value.bottom.isFinite;

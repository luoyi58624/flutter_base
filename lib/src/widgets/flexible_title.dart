part of flutter_base;

/// 用于FlexibleSpaceBar组件的title，当标题栏处于放大状态时，标题为隐藏状态，当向下滚动标题栏回归正常后再显示标题
class FlexibleTitleWidget extends StatefulWidget {
  const FlexibleTitleWidget({super.key, required this.child});

  final Widget child;

  @override
  State<FlexibleTitleWidget> createState() => _FlexibleTitleWidgetState();
}

class _FlexibleTitleWidgetState extends State<FlexibleTitleWidget> {
  ScrollPosition? _position;
  bool? _visible;

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _removeListener();
    _addListener();
  }

  void _addListener() {
    _position = Scrollable.of(context).position;
    _position?.addListener(_positionListener);
    _positionListener();
  }

  void _removeListener() {
    _position?.removeListener(_positionListener);
  }

  void _positionListener() {
    final FlexibleSpaceBarSettings? settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    bool visible = settings == null || settings.currentExtent <= settings.minExtent;
    if (_visible != visible) {
      setState(() {
        _visible = visible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _visible ?? false,
      child: widget.child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../example_page.dart';
import 'comparison_list.dart';
import 'scroll_mode.dart';

final _count = 10000;
final _extent = 64.0;
final _colors = [Color(0xff5178d9), Color(0xff32998b)];

/// 用一万条等高的纯色叶子 RenderBox 测量滚动开销基线。
class ElRecyclerRectanglesPage extends StatefulWidget {
  /// 创建可切换滚动容器的纯色矩形示例。
  // ignore: prefer_const_constructors_in_immutables
  ElRecyclerRectanglesPage({super.key});

  @override
  State<ElRecyclerRectanglesPage> createState() => _RectanglesPageState();
}

class _RectanglesPageState extends State<ElRecyclerRectanglesPage> {
  final _controller = ScrollController(keepScrollOffset: false);
  final _elController = ScrollController(keepScrollOffset: false);
  RecyclerExampleScrollMode _mode = .recyclerView;
  late final _list = rv.RecyclerView(controller: _controller)
    ..setLayoutManager(rv.LinearLayoutManager())
    ..setAdapter(_RectangleAdapter());

  @override
  void dispose() {
    _controller.dispose();
    _elController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '万条纯色矩形',
    actions: [
      RecyclerComparisonModeMenu(
        mode: _mode,
        onChanged: (mode) {
          if (_mode == mode) return;
          setState(() => _mode = mode);
          if (mode == .recyclerView) _list.scrollToPosition(0);
        },
      ),
    ],
    child: SafeArea(
      top: false,
      child: RecyclerComparisonList(
        mode: _mode,
        controller: _controller,
        elController: _elController,
        recyclerView: _list,
        itemCount: _count,
        itemExtent: _extent,
        itemBuilder: (_, index) => _Rectangle(_colors[index % _colors.length]),
      ),
    ),
  );
}

class _RectangleAdapter extends rv.Adapter<_RectangleHolder> {
  @override
  int getItemCount() => _count;

  // 按颜色分池，换绑不必重建条目或重新设置颜色。
  @override
  int getItemViewType(int position) => position % _colors.length;

  @override
  _RectangleHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _RectangleHolder(_colors[viewType]);

  @override
  void onBindViewHolder(_RectangleHolder holder, int position, [List<Object> payloads = const []]) {}
}

class _RectangleHolder extends rv.ViewHolder {
  _RectangleHolder(Color color) : super(_Rectangle(color));
}

class _Rectangle extends LeafRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Rectangle(this.color);

  final Color color;

  @override
  _RenderRectangle createRenderObject(BuildContext context) => _RenderRectangle(color);

  @override
  void updateRenderObject(BuildContext context, _RenderRectangle renderObject) => renderObject.color = color;
}

class _RenderRectangle extends RenderBox {
  _RenderRectangle(Color color) : _paint = Paint()..color = color;

  final Paint _paint;

  set color(Color value) {
    if (_paint.color == value) return;
    _paint.color = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size(constraints.maxWidth, _extent));

  @override
  void paint(PaintingContext context, Offset offset) => context.canvas.drawRect(offset & size, _paint);
}

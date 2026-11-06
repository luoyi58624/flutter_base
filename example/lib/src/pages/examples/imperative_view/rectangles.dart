import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_base/view.dart' as view;

import '../../../widgets/example_scrollbar.dart';
import '../../example_page.dart';
import '../recycler_view/scroll_mode.dart';

final _colors = [Colors.blue, Colors.teal, Colors.orange, Colors.purple, Colors.pink, Colors.indigo];
final _backgrounds = [for (final color in _colors) color.withValues(alpha: .12)];

/// 用同一棵命令式矩形行对比三个按需滚动容器。
class ImperativeRectanglesPage extends StatefulWidget {
  /// 创建一万条颜色矩形的示例。
  // ignore: prefer_const_constructors_in_immutables
  ImperativeRectanglesPage({super.key});

  @override
  State<ImperativeRectanglesPage> createState() => _ImperativeRectanglesPageState();
}

class _ImperativeRectanglesPageState extends State<ImperativeRectanglesPage> {
  final _official = ScrollController(keepScrollOffset: false);
  final _elController = ScrollController(keepScrollOffset: false);
  RecyclerExampleScrollMode _mode = .recyclerView;
  late final _list = rv.RecyclerView(key: ValueKey('imperative-recycler-list'), controller: _official)
    ..setLayoutManager(rv.LinearLayoutManager())
    ..setAdapter(_RectangleAdapter());

  void _choose(RecyclerExampleScrollMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _list.scrollToPosition(0);
  }

  @override
  void dispose() {
    _official.dispose();
    _elController.dispose();
    super.dispose();
  }

  Widget _content() {
    if (_mode == .elScrollView) {
      return ElScrollView(
        key: ValueKey('imperative-el-list'),
        controller: _elController,
        scrollbar: RecyclerExampleIosScrollbar(),
        children: [
          ElListView.builder(keepAlive: false, itemCount: 10000, itemBuilder: (context, index) => _RectangleRow(index)),
        ],
      );
    }
    return RecyclerExampleScrollbar(
      controller: _official,
      child: _mode == .recyclerView
          ? _list
          : ListView.builder(
              key: ValueKey('imperative-official-list'),
              controller: _official,
              itemCount: 10000,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              itemBuilder: (context, index) => _RectangleRow(index),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '命令式颜色矩形',
    actions: [
      PopupMenuButton<RecyclerExampleScrollMode>(
        key: ValueKey('imperative-menu'),
        tooltip: '列表选项',
        icon: Icon(Icons.more_vert),
        onSelected: _choose,
        itemBuilder: (context) => [
          for (final mode in RecyclerExampleScrollMode.values)
            CheckedPopupMenuItem(
              key: ValueKey('imperative-mode-${mode.name}'),
              value: mode,
              checked: _mode == mode,
              child: Text(mode.label),
            ),
        ],
      ),
    ],
    child: SafeArea(top: false, child: _content()),
  );
}

class _RectangleTree {
  final root = view.ElView(
    style: view.ElStyle(padding: .all(12), margin: .symmetric(horizontal: 16, vertical: 6)),
  );
  final first = view.ElView(style: view.ElStyle(height: 24, margin: .only(bottom: 8)));
  final second = view.ElView(style: view.ElStyle(height: 32, margin: .only(bottom: 8)));
  final third = view.ElView(style: view.ElStyle(height: 16));

  _RectangleTree() {
    root
      ..add(first)
      ..add(second)
      ..add(third);
  }

  void bind(int index) {
    root.bgColor = _backgrounds[index % _colors.length];
    first
      ..bgColor = _colors[index % _colors.length]
      ..width = 72 + index % 5 * 14;
    second
      ..bgColor = _colors[(index + 2) % _colors.length]
      ..width = 120 + index % 4 * 18;
    third.bgColor = _colors[(index + 4) % _colors.length];
  }
}

class _RectangleAdapter extends rv.Adapter<_RectangleHolder> {
  @override
  int getItemCount() => 10000;

  @override
  _RectangleHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _RectangleHolder();

  @override
  void onBindViewHolder(_RectangleHolder holder, int position, [List<Object> payloads = const []]) =>
      holder.tree.bind(position);
}

class _RectangleHolder extends rv.ViewHolder {
  _RectangleHolder() : this._(_RectangleTree());
  _RectangleHolder._(this.tree) : super(view.ElRootView(root: tree.root));
  final _RectangleTree tree;
}

class _RectangleRow extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _RectangleRow(this.index);
  final int index;

  @override
  Widget build(BuildContext context) {
    final tree = useMemoized(_RectangleTree.new)..bind(index);
    return view.ElRootView(root: tree.root);
  }
}

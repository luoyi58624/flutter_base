import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../../widgets/example_scrollbar.dart';
import '../../../widgets/plain_scroll.dart';
import '../../example_page.dart';
import 'scroll_mode.dart';

/// 用无样式的 ElView 文本对比长列表容器。
class RecyclerTextPage extends StatefulWidget {
  /// 创建一万条纯文本的滚动示例。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerTextPage({super.key});

  @override
  State<RecyclerTextPage> createState() => _RecyclerTextPageState();
}

class _RecyclerTextPageState extends State<RecyclerTextPage> {
  final _official = ScrollController(keepScrollOffset: false);
  final _elController = ScrollController(keepScrollOffset: false);
  RecyclerExampleScrollMode _mode = .recyclerView;
  late final _list = rv.RecyclerView(key: ValueKey('recycler-text-list'), controller: _official)
    ..setLayoutManager(rv.LinearLayoutManager())
    ..setAdapter(_TextAdapter());

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
    if (_mode == .plain) {
      return ExamplePlainScroll(
        key: ValueKey('text-plain-list'),
        controller: _elController,
        maxCount: 10000,
        scrollbar: RecyclerExampleIosScrollbar(),
        itemBuilder: (context, index) => ElView(child: 'Item - $index'),
      );
    }
    if (_mode == .elScrollView) {
      return ElScrollView(
        key: ValueKey('el-text-list'),
        controller: _elController,
        scrollbar: RecyclerExampleIosScrollbar(),
        children: [
          ElListView.builder(
            keepAlive: false,
            itemCount: 10000,
            itemBuilder: (context, index) => ElView(child: 'Item - $index'),
          ),
        ],
      );
    }
    if (_mode == .recyclerView2) {
      return RecyclerExampleScrollbar(
        controller: _official,
        child: ElRecyclerView2(
          key: ValueKey('recycler2-text-list'),
          controller: _official,
          itemCount: 10000,
          itemBuilder: (context, index) => ElView(child: 'Item - $index'),
        ),
      );
    }
    return RecyclerExampleScrollbar(
      controller: _official,
      child: _mode == .recyclerView
          ? _list
          : ListView.builder(
              key: ValueKey('official-text-list'),
              controller: _official,
              itemCount: 10000,
              addAutomaticKeepAlives: false,
              itemBuilder: (context, index) => ElView(child: 'Item - $index'),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '万条纯文本列表',
    actions: [
      PopupMenuButton<RecyclerExampleScrollMode>(
        key: ValueKey('text-menu'),
        tooltip: '列表选项',
        icon: Icon(Icons.more_vert),
        onSelected: _choose,
        itemBuilder: (context) => [
          for (final mode in RecyclerExampleScrollMode.values)
            CheckedPopupMenuItem(
              key: ValueKey('text-mode-${mode.name}'),
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

class _TextAdapter extends rv.Adapter<_TextHolder> {
  @override
  int getItemCount() => 10000;
  @override
  _TextHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _TextHolder();
  @override
  void onBindViewHolder(_TextHolder holder, int position, [List<Object> payloads = const []]) =>
      holder.index.value = position;
}

class _TextHolder extends rv.ViewHolder {
  _TextHolder() : this._(ValueNotifier<int>(0));
  _TextHolder._(this.index) : super(_TextRow(index));
  final ValueNotifier<int> index;
}

class _TextRow extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _TextRow(this.index);
  final ValueNotifier<int> index;

  @override
  Widget build(BuildContext context) {
    useEffect(() => index.dispose, [index]);
    final value = useValueListenable(index);
    return ElView(child: 'Item - $value');
  }
}

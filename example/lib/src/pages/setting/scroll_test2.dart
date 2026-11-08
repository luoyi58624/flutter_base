import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

final _itemCount = 200;
final _itemExtent = 64.0;
final _colors = [Color(0xff5178d9), Color(0xff32998b), Color(0xffd98a32), Color(0xffc45b6e), Color(0xff6b5bd9)];

/// 用 RecyclerView 展示一列可回收的纯色矩形。
class ScrollTest2 extends HookWidget {
  /// 创建纵向色块列表。
  ScrollTest2({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useScrollController(keepScrollOffset: false);
    // 容器在首次构建时完成布局器和适配器装配，避免每次重建都换绑。
    final list = useMemoized(
      () => rv.RecyclerView(controller: controller)
        ..setLayoutManager(rv.LinearLayoutManager())
        ..setPadding(16, 16, 16, 16)
        ..setAdapter(_BlockAdapter()),
    );

    return Scaffold(
      backgroundColor: context.elTheme.fill,
      appBar: AppBar(title: Text('RecyclerView 色块')),
      body: list,
    );
  }
}

class _BlockAdapter extends rv.Adapter<_BlockHolder> {
  @override
  int getItemCount() => _itemCount;

  @override
  _BlockHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _BlockHolder();

  @override
  void onBindViewHolder(_BlockHolder holder, int position, [List<Object> payloads = const []]) {
    holder.index.value = position;
  }
}

class _BlockHolder extends rv.ViewHolder {
  _BlockHolder() : this._(ValueNotifier(0));

  _BlockHolder._(this.index) : super(_ColorBlock(index));

  /// 回收后复用同一色块，绑定只更新序号，颜色由序号派生。
  final ValueNotifier<int> index;
}

class _ColorBlock extends HookWidget {
  _ColorBlock(this.index);

  final ValueNotifier<int> index;

  @override
  Widget build(BuildContext context) {
    useEffect(() => index.dispose, [index]);
    final value = useValueListenable(index);
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: _itemExtent,
        child: ColoredBox(
          color: _colors[value % _colors.length],
          child: Center(
            child: Text('$value', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

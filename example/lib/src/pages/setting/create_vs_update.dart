import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

final _itemCount = 100;

/// 记录一条路径上的创建、销毁和就地更新次数。
class _Stat {
  int created = 0;
  int disposed = 0;
  int updated = 0;
  int lastCreated = 0;
  int lastDisposed = 0;
  int lastUpdated = 0;
  int lastMicros = 0;
}

/// 对照 ListView 换键重建和 RecyclerView 原位更新。
class CreateVsUpdatePage extends HookWidget {
  /// 创建带「重建」「更新」两个开关的对照页。
  CreateVsUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final generation = useState(0);
    final enabled = useState(false);
    final revision = useState(0);
    final createStat = useMemoized(_Stat.new);
    final updateStat = useMemoized(_Stat.new);
    // 回收列表只装配一次，父级重建不能把它换成新实例。
    final updateList = useMemoized(
      () => rv.RecyclerView()
        ..setLayoutManager(rv.LinearLayoutManager())
        ..setAdapter(_UpdateAdapter(enabled, updateStat)),
    );

    useEffect(() {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) revision.value++;
      });
      return null;
    }, const []);

    // 在变更前记下基线，帧结束后算出这一次新增的次数和耗时。
    void record(_Stat stat, VoidCallback change) {
      final created = stat.created;
      final disposed = stat.disposed;
      final updated = stat.updated;
      final watch = Stopwatch()..start();
      change();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        stat
          ..lastCreated = stat.created - created
          ..lastDisposed = stat.disposed - disposed
          ..lastUpdated = stat.updated - updated
          ..lastMicros = watch.elapsedMicroseconds;
        revision.value++;
      });
    }

    return Scaffold(
      backgroundColor: context.elTheme.fill,
      appBar: AppBar(title: Text('创建与更新')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('重建会拆掉 ListView 的可见 State；更新只刷新 RecyclerView 已经挂上的条目。'),
          ),
          SwitchListTile(
            key: ValueKey('create-switch'),
            title: Text('重建'),
            isThreeLine: true,
            subtitle: Text(_statLabel(createStat), key: ValueKey('create-stat')),
            value: generation.value.isOdd,
            onChanged: (_) => record(createStat, () => generation.value++),
          ),
          SwitchListTile(
            key: ValueKey('update-switch'),
            title: Text('更新'),
            isThreeLine: true,
            subtitle: Text(_statLabel(updateStat), key: ValueKey('update-stat')),
            value: enabled.value,
            onChanged: (value) => record(updateStat, () => enabled.value = value),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('ListView'),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _itemCount,
                          addAutomaticKeepAlives: false,
                          itemBuilder: (context, index) {
                            // 键随开关变化，旧 Element 不能更新到新控件，只能销毁再创建。
                            return _CreateTile(
                              key: ValueKey('${generation.value}-$index'),
                              generation: generation.value,
                              index: index,
                              cost: createStat,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('RecyclerView'),
                      Expanded(child: updateList),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _statLabel(_Stat stat) {
  final ms = (stat.lastMicros / 1000).toStringAsFixed(1);
  return '上次创建 ${stat.lastCreated} 上次销毁 ${stat.lastDisposed} 上次更新 ${stat.lastUpdated} · $ms ms\n'
      '累计创建 ${stat.created} 累计销毁 ${stat.disposed} 累计更新 ${stat.updated}';
}

class _CreateTile extends StatefulWidget {
  _CreateTile({super.key, required this.generation, required this.index, required this.cost});

  final int generation;
  final int index;
  final _Stat cost;

  @override
  State<_CreateTile> createState() => _CreateTileState();
}

class _CreateTileState extends State<_CreateTile> {
  @override
  void initState() {
    super.initState();
    widget.cost.created++;
  }

  @override
  void dispose() {
    widget.cost.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.generation.isOdd;
    return SizedBox(
      height: 48,
      child: ColoredBox(
        color: on ? Color(0xffc45b6e) : Color(0xff5178d9),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('${widget.index}', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _UpdateAdapter extends rv.Adapter<_UpdateHolder> {
  _UpdateAdapter(this.enabled, this.cost);

  final ValueNotifier<bool> enabled;
  final _Stat cost;

  @override
  int getItemCount() => _itemCount;

  @override
  _UpdateHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => _UpdateHolder(enabled, cost);

  @override
  void onBindViewHolder(_UpdateHolder holder, int position, [List<Object> payloads = const []]) {}
}

class _UpdateHolder extends rv.ViewHolder {
  _UpdateHolder(ValueNotifier<bool> enabled, _Stat cost) : super(_UpdateTile(enabled, cost));
}

class _UpdateTile extends StatefulWidget {
  _UpdateTile(this.enabled, this.cost);

  final ValueNotifier<bool> enabled;
  final _Stat cost;

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  @override
  void initState() {
    super.initState();
    widget.cost.created++;
    widget.enabled.addListener(_onChanged);
  }

  /// 开关只通知已挂上的 State，不换控件实例。
  void _onChanged() {
    widget.cost.updated++;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.enabled.removeListener(_onChanged);
    widget.cost.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled.value;
    return SizedBox(
      height: 48,
      child: ColoredBox(
        color: on ? Color(0xff32998b) : Color(0xffd98a32),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(on ? '开' : '关', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

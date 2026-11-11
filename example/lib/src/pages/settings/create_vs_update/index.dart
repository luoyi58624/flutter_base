import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/desktop.dart';

/// 记录一个控件的创建、销毁和就地更新次数。
class _Stat {
  int created = 0;
  int disposed = 0;
  int updated = 0;
  int lastCreated = 0;
  int lastDisposed = 0;
  int lastUpdated = 0;
}

/// 用两个开关对照单个控件的销毁重建和原位更新。
class CreateVsUpdatePage extends HookWidget {
  /// 创建「重建」「更新」两个开关及各自的色块。
  CreateVsUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final generation = useState(0);
    final enabled = useState(false);
    final revision = useState(0);
    final createStat = useMemoized(_Stat.new);
    final updateStat = useMemoized(_Stat.new);

    useEffect(() {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) revision.value++;
      });
      return null;
    }, const []);

    // 销毁发生在本帧构建之后，帧结束再读取计数。
    void record(_Stat stat, VoidCallback change) {
      final created = stat.created;
      final disposed = stat.disposed;
      final updated = stat.updated;
      change();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        stat
          ..lastCreated = stat.created - created
          ..lastDisposed = stat.disposed - disposed
          ..lastUpdated = stat.updated - updated;
        revision.value++;
      });
    }

    return Scaffold(
      backgroundColor: context.elTheme.fill,
      appBar: AppBar(title: Text('创建与更新')),
      body: Column(
        children: [
          SwitchListTile(
            key: ValueKey('create-switch'),
            title: Text('重建'),
            subtitle: Text(_statLabel(createStat), key: ValueKey('create-stat')),
            value: generation.value.isOdd,
            onChanged: (_) => record(createStat, () => generation.value++),
          ),
          _CreateBox(key: ValueKey(generation.value), generation: generation.value, cost: createStat),
          SwitchListTile(
            key: ValueKey('update-switch'),
            title: Text('更新'),
            subtitle: Text(_statLabel(updateStat), key: ValueKey('update-stat')),
            value: enabled.value,
            onChanged: (value) => record(updateStat, () => enabled.value = value),
          ),
          _UpdateBox(enabled, updateStat),
        ],
      ),
    );
  }
}

String _statLabel(_Stat stat) {
  return '上次创建 ${stat.lastCreated} 上次销毁 ${stat.lastDisposed} 上次更新 ${stat.lastUpdated}\n'
      '累计创建 ${stat.created} 累计销毁 ${stat.disposed} 累计更新 ${stat.updated}';
}

class _CreateBox extends StatefulWidget {
  _CreateBox({super.key, required this.generation, required this.cost});

  final int generation;
  final _Stat cost;

  @override
  State<_CreateBox> createState() => _CreateBoxState();
}

class _CreateBoxState extends State<_CreateBox> {
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
      height: 72,
      child: ColoredBox(
        color: on ? Color(0xffc45b6e) : Color(0xff5178d9),
        child: Center(
          child: Text('重建 ${widget.generation}', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
    );
  }
}

class _UpdateBox extends StatefulWidget {
  _UpdateBox(this.enabled, this.cost);

  final ValueNotifier<bool> enabled;
  final _Stat cost;

  @override
  State<_UpdateBox> createState() => _UpdateBoxState();
}

class _UpdateBoxState extends State<_UpdateBox> {
  @override
  void initState() {
    super.initState();
    widget.cost.created++;
    widget.enabled.addListener(_onChanged);
  }

  /// 同一个 State 接着用，只刷新开关值。
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
      height: 72,
      child: ColoredBox(
        color: on ? Color(0xff32998b) : Color(0xffd98a32),
        child: Center(
          child: Text(on ? '更新 开' : '更新 关', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
    );
  }
}

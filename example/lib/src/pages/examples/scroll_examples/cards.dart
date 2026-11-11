import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../layout/example_page.dart';
import '../../../widgets/example_image.dart';
import 'scroll_mode.dart';
import 'comparison_list.dart';
import '../../../widgets/panel.dart';

/// 用一万张生态观察卡片对比复杂内容的回收复用与局部更新。
class RecyclerCardsPage extends StatefulWidget {
  /// 创建包含离线照片、阴影和按压反馈的信息卡片示例。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerCardsPage({super.key});

  @override
  State<RecyclerCardsPage> createState() => _RecyclerCardsPageState();
}

enum _CardsAction { refreshVisible, first, last, clear }

class _RecyclerCardsPageState extends State<RecyclerCardsPage> {
  final _controller = ScrollController(keepScrollOffset: false);
  final _activeCount = ValueNotifier<int>(0);
  SliverExampleMode _mode = .recycler;
  late final _adapter = _ObservationRecords((count) => _activeCount.value = count);

  ScrollController get _currentController => _controller;

  void _refreshVisible() {
    if (!_currentController.hasClients) return;
    final extent = _cardExtent(context);
    final first = (_controller.offset / extent).floor();
    final last = ((_controller.offset + _controller.position.viewportDimension) / extent).ceil() - 1;
    if (first >= 0 && last >= first) _adapter.refreshRange(first, last);
  }

  void _scrollTo(int index) {
    if (_currentController.hasClients) {
      _currentController.jumpTo((index * _cardExtent(context)).clamp(0, _currentController.position.maxScrollExtent));
    }
  }

  void _choose(Object option) {
    if (option case final SliverExampleMode mode) {
      if (_mode == mode) return;
      setState(() => _mode = mode);
      if (_controller.hasClients) _controller.jumpTo(0);
      return;
    }
    switch (option as _CardsAction) {
      case .refreshVisible:
        _refreshVisible();
      case .first:
        _scrollTo(0);
      case .last:
        _scrollTo(_adapter.getItemCount() - 1);
      case .clear:
        _adapter.clearActive();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _activeCount.dispose();
    _adapter.disposeModels();
    super.dispose();
  }

  Widget _row(BuildContext context, int index) => RepaintBoundary(
    child: _OfficialObservationRow(key: ValueKey(index), adapter: _adapter, record: _adapter.recordAt(index)),
  );

  Widget _scrollContent(BuildContext context) => SliverComparisonList(
    mode: _mode,
    controller: _controller,
    itemCount: _adapter.getItemCount(),
    itemBuilder: _row,
    itemType: (index) => index % 2,
    recycledItemBuilder: (context, index) => HookBuilder(
      builder: (context) {
        final model = useMemoized(_adapter.createModel);
        useEffect(() {
          void bind() {
            final record = _adapter.recordAt(index.value);
            model.bind(record, _adapter.activeIds.contains(record.id));
          }

          bind();
          index.addListener(bind);
          return () => index.removeListener(bind);
        }, [index]);
        return useMemoized(
          () => _ObservationRow(model, index.value % 2, _adapter.toggleActive, () => _adapter.releaseModel(model)),
          [model],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: '复杂信息卡片',
    actions: [
      ValueListenableBuilder<int>(
        valueListenable: _activeCount,
        builder: (context, count, child) =>
            Text('$count / 10000', key: ValueKey('cards-active-count'), style: TextStyle(fontSize: 12)),
      ),
      PopupMenuButton<Object>(
        key: ValueKey('cards-menu'),
        tooltip: '卡片选项',
        icon: Icon(Icons.more_vert),
        onSelected: _choose,
        itemBuilder: (context) => [
          for (final mode in SliverExampleMode.values)
            CheckedPopupMenuItem(
              key: ValueKey('cards-mode-${mode.name}'),
              value: mode,
              checked: _mode == mode,
              child: Text(mode.label),
            ),
          PopupMenuDivider(),
          PopupMenuItem(
            key: ValueKey('cards-refresh-visible'),
            value: _CardsAction.refreshVisible,
            child: Text('更新可见卡片数据'),
          ),
          PopupMenuItem(key: ValueKey('cards-first'), value: _CardsAction.first, child: Text('首张卡片')),
          PopupMenuItem(key: ValueKey('cards-last'), value: _CardsAction.last, child: Text('末张卡片')),
          PopupMenuItem(key: ValueKey('cards-clear'), value: _CardsAction.clear, child: Text('清除激活')),
        ],
      ),
    ],
    child: SafeArea(top: false, child: _scrollContent(context)),
  );
}

double _cardExtent(BuildContext context) => 540 + math.max(0.0, MediaQuery.textScalerOf(context).scale(14) - 14) * 14;

class _Observation {
  _Observation(this.id)
    : photo = id % 2,
      title = '${_places[id % _places.length]} · 观测 #${(id + 1).toString().padLeft(5, '0')}',
      code = 'FIELD / ${(700000 + id).toString()}',
      description =
          '${_descriptions[id % _descriptions.length]} 本次沿 ${id % 9 + 2} 号样线记录栖息环境与活动轨迹，'
          '为下一轮季节调查补充现场资料。',
      location = '${_places[id % _places.length]} · 样区 ${id % 37 + 1}',
      author = '调查员 ${String.fromCharCode(65 + id % 26)}${id % 12 + 1}',
      altitude = '${480 + id % 1800} m',
      visits = 1200 + id * 13,
      progress = .35 + id % 60 / 100;

  static final _places = ['云岭森林', '青岚湿地', '南山自然保护区', '白露溪谷', '杉木山地', '苍鹭湾'];
  static final _descriptions = [
    '晨雾散去之后，林冠之间开始出现细碎鸣声。我们沿着溪流寻找新的观察点。',
    '傍晚的林缘格外安静，枝头留下清晰的停栖痕迹，远处传来短促的回应。',
    '这片连绵的针阔混交林保留了完整的生态层次，适合长期记录鸟类种群变化。',
  ];

  final int id;
  final int photo;
  final String title;
  final String code;
  final String description;
  final String location;
  final String author;
  final String altitude;
  int visits;
  double progress;
  int revision = 0;
}

class _ObservationModel {
  final record = ValueNotifier<_Observation?>(null);
  final active = ValueNotifier<bool>(false);
  final visits = ValueNotifier<int>(0);
  final progress = ValueNotifier<double>(0);
  final revision = ValueNotifier<int>(0);

  void bind(_Observation value, bool selected) {
    record.value = value;
    active.value = selected;
    bindStatistics(value);
  }

  void bindStatistics(_Observation value) {
    visits.value = value.visits;
    progress.value = value.progress;
    revision.value = value.revision;
  }

  void dispose() {
    record.dispose();
    active.dispose();
    visits.dispose();
    progress.dispose();
    revision.dispose();
  }
}

class _ObservationRecords {
  _ObservationRecords(this.onCountChanged);

  final ValueChanged<int> onCountChanged;
  // 记录随首次访问创建，复访继续使用已更新的业务数据；类型查询不触发创建。
  final records = <int, _Observation>{};
  final activeIds = <int>{};
  final _models = <_ObservationModel>{};

  _Observation recordAt(int index) => records.putIfAbsent(index, () => _Observation(index));

  _ObservationModel createModel() {
    final model = _ObservationModel();
    _models.add(model);
    return model;
  }

  void releaseModel(_ObservationModel model) {
    if (_models.remove(model)) model.dispose();
  }

  void disposeModels() {
    for (final model in _models) {
      model.dispose();
    }
    _models.clear();
    records.clear();
  }

  int getItemCount() => 10000;

  void toggleActive(int id) {
    final selected = activeIds.add(id);
    if (!selected) activeIds.remove(id);
    // 激活只改变现有卡片的绘制与语义，不让列表重新布局或重新绑定其它字段。
    for (final model in _models) {
      if (model.record.value?.id == id) model.active.value = selected;
    }
    onCountChanged(activeIds.length);
  }

  void clearActive() {
    if (activeIds.isEmpty) return;
    activeIds.clear();
    for (final model in _models) {
      model.active.value = false;
    }
    onCountChanged(0);
  }

  void refreshRange(int first, int last) {
    first = first.clamp(0, getItemCount() - 1);
    last = last.clamp(first, getItemCount() - 1);
    for (var index = first; index <= last; index++) {
      final record = recordAt(index);
      record.visits += 7 + index % 5;
      record.progress = record.progress >= .98 ? .42 : math.min(1.0, record.progress + .07);
      record.revision++;
    }
    // 每个 holder 只订阅自己需要的叶子；静态文案、图片和排版没有收到刷新通知。
    for (final model in _models) {
      final record = model.record.value;
      if (record != null && record.id >= first && record.id <= last) model.bindStatistics(record);
    }
  }
}

class _OfficialObservationRow extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _OfficialObservationRow({super.key, required this.adapter, required this.record});
  final _ObservationRecords adapter;
  final _Observation record;
  @override
  State<_OfficialObservationRow> createState() => _OfficialObservationRowState();
}

class _OfficialObservationRowState extends State<_OfficialObservationRow> {
  late final _model = widget.adapter.createModel();
  late final _row = _ObservationRow(
    _model,
    widget.record.photo,
    widget.adapter.toggleActive,
    () => widget.adapter.releaseModel(_model),
  );

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() => _model.bind(widget.record, widget.adapter.activeIds.contains(widget.record.id));

  @override
  void didUpdateWidget(_OfficialObservationRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind();
  }

  @override
  Widget build(BuildContext context) => _row;
}

class _ObservationRow extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ObservationRow(this.model, this.photo, this.onActivate, this.onDispose);
  final _ObservationModel model;
  final int photo;
  final ValueChanged<int> onActivate;
  final VoidCallback onDispose;

  @override
  State<_ObservationRow> createState() => _ObservationRowState();
}

class _ObservationRowState extends State<_ObservationRow> {
  _ObservationModel get model => widget.model;
  int get photo => widget.photo;

  @override
  void dispose() {
    // 回收池仍保留挂载树，只有真正卸载卡片时才释放叶子订阅与模型。
    widget.onDispose();
    super.dispose();
  }

  void _activate() {
    final record = model.record.value;
    if (record != null) widget.onActivate(record.id);
  }

  Widget _text(String Function(_Observation record) value, {Key? key, TextStyle? style, int maxLines = 1}) =>
      ValueListenableBuilder<_Observation?>(
        valueListenable: model.record,
        builder: (context, record, child) =>
            Text(record == null ? '' : value(record), key: key, style: style, maxLines: maxLines, overflow: .ellipsis),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.brightness == .dark ? Color(0xff8dd9b3) : Color(0xff28795b);
    final secondary = TextStyle(fontSize: 12, color: colors.onSurfaceVariant);
    final statStyle = TextStyle(fontSize: 19, fontWeight: .w700, color: colors.onSurface);
    final content = Column(
      crossAxisAlignment: .stretch,
      children: [
        ClipRRect(
          borderRadius: .vertical(top: .circular(20)),
          child: SizedBox(
            height: 146,
            child: Stack(
              fit: .expand,
              children: [
                Image.asset(
                  'assets/recycler_cards/${photo == 0 ? 'owl.jpg' : 'owl-2.jpg'}',
                  fit: .cover,
                  alignment: photo == 0 ? Alignment(0, -.15) : Alignment.center,
                  cacheWidth: 960,
                  excludeFromSemantics: true,
                  frameBuilder: exampleImageFrame,
                  errorBuilder: exampleImageError,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: .topCenter,
                      end: .bottomCenter,
                      colors: [Colors.black.withValues(alpha: .04), Colors.black.withValues(alpha: .72)],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 14,
                  child: _CardPill('FIELD NOTES', Icons.explore_outlined, foreground: Colors.white),
                ),
                Positioned(
                  right: 14,
                  bottom: 15,
                  child: Icon(Icons.camera_alt_outlined, color: Colors.white.withValues(alpha: .85), size: 18),
                ),
                Positioned(
                  left: 16,
                  right: 48,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 3,
                    children: [
                      Text(
                        photo == 0 ? '林间夜行者' : '枝头守望者',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: .w700),
                      ),
                      _text((record) => record.location, style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: .all(16),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Icon(Icons.forest_outlined, size: 15, color: accent),
                    Expanded(child: _text((record) => record.code, style: secondary.copyWith(letterSpacing: 1))),
                    Icon(Icons.star_rounded, size: 15, color: Color(0xffd6a354)),
                    Text('4.9', style: secondary),
                  ],
                ),
                SizedBox(height: 9),
                _text(
                  (record) => record.title,
                  key: ValueKey('cards-title'),
                  style: TextStyle(fontSize: 19, fontWeight: .w700, height: 1.2),
                ),
                SizedBox(height: 8),
                _text(
                  (record) => record.description,
                  style: secondary.copyWith(fontSize: 13, height: 1.5),
                  maxLines: 2,
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _CardPill('鸟类调查', Icons.flutter_dash, foreground: accent),
                    _CardPill('栖息地记录', Icons.landscape_outlined, foreground: colors.onSurfaceVariant),
                    _CardPill('离线可用', Icons.offline_pin_outlined, foreground: colors.onSurfaceVariant),
                  ],
                ),
                Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: _CardStatistic(
                        label: '观察次数',
                        child: ValueListenableBuilder<int>(
                          valueListenable: model.visits,
                          builder: (context, value, child) =>
                              Text('$value', key: ValueKey('cards-visits'), style: statStyle),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _CardStatistic(
                        label: '记录完整度',
                        child: ValueListenableBuilder<double>(
                          valueListenable: model.progress,
                          builder: (context, value, child) => Text('${(value * 100).round()}%', style: statStyle),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _CardStatistic(
                        label: '样区海拔',
                        child: _text((record) => record.altitude, style: statStyle),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                ClipRRect(
                  borderRadius: .circular(8),
                  child: ValueListenableBuilder<double>(
                    valueListenable: model.progress,
                    builder: (context, value, child) => LinearProgressIndicator(
                      key: ValueKey('cards-progress'),
                      value: value,
                      minHeight: 5,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: .12),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .65)),
                SizedBox(height: 12),
                Row(
                  spacing: 9,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: accent.withValues(alpha: .12),
                      child: Icon(Icons.person_outline_rounded, color: accent, size: 19),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        spacing: 2,
                        children: [
                          _text((record) => record.author, style: TextStyle(fontSize: 12, fontWeight: .w600)),
                          ValueListenableBuilder<int>(
                            valueListenable: model.revision,
                            builder: (context, revision, child) => Text(
                              revision == 0 ? '现场记录 · 等待同步' : '现场记录 · 已更新 $revision 次',
                              key: ValueKey('cards-updated'),
                              style: secondary.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: model.active,
                      builder: (context, active, child) => Icon(
                        active ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                        color: active ? accent : colors.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return SizedBox(
      height: _cardExtent(context),
      child: Padding(
        padding: .symmetric(horizontal: 16, vertical: 10),
        child: Align(
          alignment: .topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 760),
            child: ValueListenableBuilder<bool>(
              valueListenable: model.active,
              child: content,
              builder: (context, active, child) => Semantics(
                key: ValueKey('cards-activate'),
                button: true,
                selected: active,
                label: '激活或取消激活观察卡片',
                onTap: _activate,
                child: ExamplePanel(
                  event: ElEvent(onTap: (_) => _activate()),
                  style: ElStyle(
                    width: '100%',
                    height: '100%',
                    backgroundColor: active
                        ? Color.alphaBlend(accent.withValues(alpha: .045), colors.surface)
                        : colors.surface,
                    borderRadius: .circular(20),
                    border: .all(
                      borderWidth: active ? 2 : 1,
                      borderColor: active
                          ? accent.withValues(alpha: .65)
                          : colors.outlineVariant.withValues(alpha: .55),
                    ),
                    onTap: ElStyle(transform: .scale(.98)),
                    transition: [ElTransition.field(.transform, Duration(milliseconds: 100), Curves.easeOut)],
                  ).withShadow(type: .floating, level: .md, strength: .5),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardPill extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _CardPill(this.label, this.icon, {required this.foreground});
  final String label;
  final IconData icon;
  final Color foreground;

  @override
  Widget build(BuildContext context) => ElView(
    style: ElStyle(
      padding: .symmetric(horizontal: 8, vertical: 5),
      backgroundColor: foreground.withValues(alpha: .09),
      borderRadius: .circular(8),
    ),
    child: Row(
      mainAxisSize: .min,
      spacing: 4,
      children: [
        Icon(icon, size: 13, color: foreground),
        Text(label, style: TextStyle(fontSize: 10, color: foreground)),
      ],
    ),
  );
}

class _CardStatistic extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _CardStatistic({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: .start,
    spacing: 3,
    children: [
      FittedBox(fit: .scaleDown, alignment: .centerLeft, child: child),
      Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ],
  );
}

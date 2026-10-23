import 'package:flutter/material.dart';
import 'package:flutter_base/ui.dart';

const _ink = Color(0xff202839);
const _muted = Color(0xff697386);
const _blue = Color(0xff385ddd);
const _background = Color(0xfff3f5f9);

/// 新点击识别器的交互测试页，展示连击、冒泡及官方手势竞争。
class CustomGesturesPage extends StatefulWidget {
  /// 创建点击测试页。
  const CustomGesturesPage({super.key});

  @override
  State<CustomGesturesPage> createState() => _CustomGesturesPageState();
}

class _CustomGesturesPageState extends State<CustomGesturesPage> {
  final _counts = <String, int>{};
  final _pressed = <String>{};
  final _entries = <_LogEntry>[];
  final _bounds = <String, GlobalKey>{};
  final _scrollController = ScrollController();
  final _logRevision = ValueNotifier<int>(0);
  late ElPressGestureRecognizer _basic;
  late ElPressGestureRecognizer _bubbleParent;
  late ElPressGestureRecognizer _bubbleChild;
  late ElPressGestureRecognizer _elInOfficial;
  late ElPressGestureRecognizer _elOutsideOfficial;
  late ElPressGestureRecognizer _scrollPress;
  bool _deferSingle = false;
  bool _stopBubble = false;
  bool _ignoreCallbacks = false;
  int _sequence = 0;

  static const _sourceNames = {
    'basic': '基础点击',
    'bubbleChild': 'El 子级',
    'bubbleParent': 'El 父级',
    'mixedEl': 'El 内层',
    'officialOuter': '官方外层',
    'mixedElOuter': 'El 外层',
    'officialChild': '官方内层',
    'scroll': '列表首行',
  };

  @override
  void initState() {
    super.initState();
    _createRecognizers();
  }

  ElPressGestureRecognizer _press(
    String source, {
    String? tapCounter,
    ElPressGestureRecognizer? parent,
  }) {
    _bounds.putIfAbsent(source, () => GlobalKey());
    return ElPressGestureRecognizer(
        parent: parent,
        tapSlopTolerance: double.infinity,
      )
      ..onTapDown = _handler(source, pressed: true)
      ..onTapUp = _handler(source, pressed: false)
      ..onTap = _handler(source, counter: tapCounter)
      ..onTapCancel = _handler(
        source,
        pressed: false,
        counter: source == 'scroll' ? 'scrollCancel' : null,
      );
  }

  ElPressGestureCallback _handler(
    String source, {
    bool? pressed,
    String? counter,
  }) =>
      (event) =>
          _recordEvent(source, event, pressed: pressed, counter: counter);

  void _createRecognizers() {
    _basic = _press('basic', tapCounter: 'tap')
      ..deferTap = _deferSingle
      ..onDoubleTapDown = _handler('basic')
      ..onTripleTapDown = _handler('basic')
      ..onDoubleTap = _handler('basic', counter: 'doubleTap')
      ..onTripleTap = _handler('basic', counter: 'tripleTap')
      ..onLongPress = _handler('basic', counter: 'longPress', pressed: true);
    _wireMouseButtons();
    _bubbleParent = _press('bubbleParent', tapCounter: 'bubbleParent');
    _bubbleChild =
        _press('bubbleChild', tapCounter: 'bubbleChild', parent: _bubbleParent)
          ..onTapDown = (event) {
            if (_stopBubble) event.stopPropagation();
            _recordEvent('bubbleChild', event, pressed: true);
          }
          ..onTap = (event) {
            if (_stopBubble) event.stopPropagation();
            _recordEvent('bubbleChild', event, counter: 'bubbleChild');
          };
    _elInOfficial = _press('mixedEl', tapCounter: 'mixedEl');
    _elOutsideOfficial = _press('mixedElOuter', tapCounter: 'mixedElOuter');
    _scrollPress = _press('scroll', tapCounter: 'scrollTap');
  }

  void _wireMouseButtons() {
    _basic
      ..onSecondaryTapDown = _handler('basic', pressed: true)
      ..onSecondaryTapUp = _handler('basic', pressed: false)
      ..onSecondaryTap = _handler('basic', counter: 'secondaryTap')
      ..onTertiaryTapDown = _handler('basic', pressed: true)
      ..onTertiaryTapUp = _handler('basic', pressed: false)
      ..onTertiaryTap = _handler('basic', counter: 'tertiaryTap')
      ..onForwardTapDown = _handler('basic', pressed: true)
      ..onForwardTapUp = _handler('basic', pressed: false)
      ..onForwardTap = _handler('basic', counter: 'forwardTap')
      ..onBackTapDown = _handler('basic', pressed: true)
      ..onBackTapUp = _handler('basic', pressed: false)
      ..onBackTap = _handler('basic', counter: 'backTap');
  }

  Iterable<ElPressGestureRecognizer> get _recognizers => [
    _basic,
    _bubbleChild,
    _bubbleParent,
    _elInOfficial,
    _elOutsideOfficial,
    _scrollPress,
  ];

  void _recordEvent(
    String source,
    ElPressGestureDetails event, {
    bool? pressed,
    String? counter,
  }) => _record(
    source,
    event.phase.name,
    pressed: pressed,
    counter: counter,
    position: event.localPosition,
    taps: event.tapCount,
    cancelReason: switch (event.cancelReason) {
      ElGestureCancelReason.longPressAccepted => '长按已成立',
      ElGestureCancelReason.arenaRejected => '其他手势取得所有权',
      ElGestureCancelReason.rejected => '移动、按钮或指针条件不满足',
      ElGestureCancelReason.pointerCanceled => '平台取消指针',
      ElGestureCancelReason.canceled => '宿主取消或生命周期结束',
      null => null,
    },
  );

  void _record(
    String source,
    String phase, {
    bool? pressed,
    String? counter,
    Offset? position,
    int taps = 0,
    String? cancelReason,
  }) {
    if (_ignoreCallbacks || !mounted) return;
    setState(() {
      if (pressed == true) _pressed.add(source);
      if (pressed == false) _pressed.remove(source);
      if (counter != null) {
        _counts.update(counter, (v) => v + 1, ifAbsent: () => 1);
      }
      // 回调对象会在冒泡时重定位，只保留此刻的值，不保存可变事件对象。
      _entries.insert(
        0,
        _LogEntry(
          ++_sequence,
          _sourceNames[source]!,
          phase,
          position,
          taps,
          cancelReason,
        ),
      );
      if (_entries.length > 24) _entries.removeLast();
    });
    _logRevision.value++;
  }

  void _reset() {
    _ignoreCallbacks = true;
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _createRecognizers();
    _ignoreCallbacks = false;
    setState(() {
      _counts.clear();
      _pressed.clear();
      _entries.clear();
      _sequence = 0;
    });
    _logRevision.value++;
  }

  void _showLogs() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _background,
      builder: (context) => FractionallySizedBox(
        heightFactor: .85,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ValueListenableBuilder<int>(
              valueListenable: _logRevision,
              builder: (_, _, _) => _logCard(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ignoreCallbacks = true;
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _scrollController.dispose();
    _logRevision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: const ValueKey('gesture.page.capture'),
    child: Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('自定义手势'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const ValueKey('gesture.logs'),
            onPressed: _showLogs,
            tooltip: '事件记录',
            icon: const Icon(Icons.receipt_long_outlined, size: 21),
          ),
          TextButton.icon(
            key: const ValueKey('gesture.reset'),
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded, size: 19),
            label: const Text('重置记录'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1080;
          final tests = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              _basicCard(),
              _bubbleCard(),
              _mixedCard(),
              _scrollCard(),
            ],
          );
          const heading = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Text(
                '点击交互测试',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Text(
                '在下方区域操作，观察计数与事件顺序。蓝色为 El 测试区，橙色为官方测试区。',
                style: TextStyle(color: _muted, height: 1.6),
              ),
            ],
          );
          final narrowContent = SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [heading, tests, _logCard()],
            ),
          );
          return Padding(
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: wide
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: [
                          heading,
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 20,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(child: tests),
                                ),
                                SizedBox(
                                  width: 340,
                                  child: SingleChildScrollView(
                                    child: _logCard(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : narrowContent,
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _basicCard() => _TestCard(
    number: '01',
    title: '点击与按压',
    description: '单击、连续双击 / 三击，或按住 500 毫秒。鼠标还可测试右键、中键和侧键。',
    children: [
      _surface(
        'basic',
        _basic,
        targetKey: 'gesture.basic.target',
        child: _area(
          'basic',
          title: _pressed.contains('basic') ? '按压中…' : '在这里点击',
          description: '触摸与鼠标均可操作',
          icon: Icons.touch_app_outlined,
        ),
      ),
      _metrics(const [
        ('tap', '单击'),
        ('doubleTap', '双击'),
        ('tripleTap', '三击'),
        ('longPress', '长按'),
        ('secondaryTap', '右键'),
        ('tertiaryTap', '中键'),
        ('forwardTap', '前进'),
        ('backTap', '后退'),
      ]),
      SwitchListTile.adaptive(
        key: const ValueKey('gesture.defer'),
        contentPadding: EdgeInsets.zero,
        title: const Text('等待双击后再触发单击'),
        subtitle: const Text('关闭时，每次点击立即计数；双击、三击额外计数。'),
        value: _deferSingle,
        onChanged: (value) => setState(() {
          _deferSingle = value;
          _basic.deferTap = value;
        }),
      ),
    ],
  );

  Widget _bubbleCard() => _TestCard(
    number: '02',
    title: 'El 父子冒泡',
    description: '点击内层区域，默认依次通知子级、父级。打开开关后只通知子级。',
    children: [
      _surface(
        'bubbleParent',
        _bubbleParent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _frame('bubbleParent'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              const Text('El 父级区域', style: TextStyle(color: _muted)),
              _surface(
                'bubbleChild',
                _bubbleChild,
                targetKey: 'gesture.bubble.target',
                child: _area(
                  'bubbleChild',
                  title: '点击 El 子级',
                  description: _stopBubble ? '当前仅通知子级' : '子级 → 父级',
                ),
              ),
            ],
          ),
        ),
      ),
      _metrics(const [('bubbleChild', '子级点击'), ('bubbleParent', '父级点击')]),
      SwitchListTile.adaptive(
        key: const ValueKey('gesture.bubble.stop'),
        contentPadding: EdgeInsets.zero,
        title: const Text('阻止向 El 父级冒泡'),
        value: _stopBubble,
        onChanged: (value) => setState(() => _stopBubble = value),
      ),
    ],
  );

  Widget _mixedCard() => _TestCard(
    number: '03',
    title: '与官方点击互斥',
    description: '点击各自内层区域，只有内层计数。外层可能先收到按下候选，随后取消。',
    children: [
      _official(
        'officialOuter',
        'mixedOfficialOuter',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _frame('officialOuter', official: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              const Text('官方外层', style: TextStyle(color: _muted)),
              _surface(
                'mixedEl',
                _elInOfficial,
                targetKey: 'gesture.elInOfficial.target',
                child: _area('mixedEl', title: '点击 El 内层'),
              ),
            ],
          ),
        ),
      ),
      _metrics(const [('mixedEl', 'El 内层'), ('mixedOfficialOuter', '官方外层')]),
      const Divider(height: 8, color: Color(0xffedf0f5)),
      _surface(
        'mixedElOuter',
        _elOutsideOfficial,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _frame('mixedElOuter'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              const Text('El 外层', style: TextStyle(color: _muted)),
              _official(
                'officialChild',
                'mixedOfficialChild',
                targetKey: 'gesture.officialInEl.target',
                child: _area('officialChild', title: '点击官方内层', official: true),
              ),
            ],
          ),
        ),
      ),
      _metrics(const [
        ('mixedOfficialChild', '官方内层'),
        ('mixedElOuter', 'El 外层'),
      ]),
    ],
  );

  Widget _scrollCard() => _TestCard(
    number: '04',
    title: '滚动时取消点击',
    description: '触摸：从首行向上滑动，应滚动并取消点击。鼠标可点击首行，使用滚轮滚动列表。',
    children: [
      DecoratedBox(
        decoration: _frame('scroll'),
        child: SizedBox(
          height: 190,
          child: ListView(
            key: const ValueKey('gesture.scroll.list'),
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            children: [
              _surface(
                'scroll',
                _scrollPress,
                targetKey: 'gesture.scroll.target',
                child: _area(
                  'scroll',
                  title: '点击，或从这里向上滑动',
                  icon: Icons.swipe_up_rounded,
                ),
              ),
              for (var i = 1; i <= 8; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Text('滚动内容 $i', style: const TextStyle(color: _muted)),
                ),
            ],
          ),
        ),
      ),
      _metrics(const [('scrollTap', '点击成功'), ('scrollCancel', '点击取消')]),
    ],
  );

  void _cancelOutside(
    String source,
    ElPressGestureRecognizer recognizer,
    PointerEvent event,
  ) {
    final render = _bounds[source]?.currentContext?.findRenderObject();
    if (render is! RenderBox ||
        !render.attached ||
        !render.hasSize ||
        !render.size.contains(render.globalToLocal(event.position))) {
      recognizer.cancelPointer(event.pointer, event: event);
    }
  }

  Widget _surface(
    String source,
    ElPressGestureRecognizer recognizer, {
    required Widget child,
    String? targetKey,
  }) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Listener(
      key: _bounds[source],
      behavior: HitTestBehavior.opaque,
      // 宿主负责元素范围，识别器负责后续输入和竞技场，不读取 RenderBox。
      onPointerDown: recognizer.addPointer,
      onPointerMove: (event) => _cancelOutside(source, recognizer, event),
      onPointerUp: (event) => _cancelOutside(source, recognizer, event),
      child: KeyedSubtree(
        key: targetKey == null ? null : ValueKey(targetKey),
        child: child,
      ),
    ),
  );

  Widget _official(
    String source,
    String counter, {
    required Widget child,
    String? targetKey,
  }) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      key: targetKey == null ? null : ValueKey(targetKey),
      behavior: HitTestBehavior.opaque,
      onTapDown: (event) => _record(
        source,
        'tapDown',
        pressed: true,
        position: event.localPosition,
      ),
      onTapUp: (event) => _record(
        source,
        'tapUp',
        pressed: false,
        position: event.localPosition,
      ),
      onTapCancel: () => _record(source, 'tapCancel', pressed: false),
      onTap: () => _record(source, 'tap', counter: counter),
      child: child,
    ),
  );

  BoxDecoration _frame(String source, {bool official = false}) {
    final color = official ? const Color(0xffb46c16) : _blue;
    return BoxDecoration(
      color: _pressed.contains(source)
          ? color.withValues(alpha: .12)
          : color.withValues(alpha: .035),
      border: Border.all(color: color.withValues(alpha: .2)),
      borderRadius: BorderRadius.circular(12),
    );
  }

  Widget _area(
    String source, {
    required String title,
    String? description,
    IconData? icon,
    bool official = false,
  }) {
    final color = official ? const Color(0xffb46c16) : _blue;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: _pressed.contains(source)
            ? color.withValues(alpha: .19)
            : color.withValues(alpha: .085),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (icon != null) Icon(icon, color: color, size: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (description != null)
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _metrics(List<(String, String)> counters) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (id, label) in counters)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
              Text(
                '${_counts[id] ?? 0}',
                key: ValueKey('count.$id'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _logCard() => _TestCard(
    number: '↗',
    title: '事件记录',
    description: '最新事件在上方；序号用于核对先后顺序。保留最近 24 条。',
    children: [
      if (_entries.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text('点击任意测试区开始', style: TextStyle(color: _muted)),
          ),
        )
      else
        SizedBox(
          height: 430,
          child: ListView.separated(
            itemCount: _entries.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 17, color: Color(0xffedf0f5)),
            itemBuilder: (_, index) {
              final entry = _entries[index];
              final canceled = entry.phase == 'tapCancel';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    '#${entry.sequence.toString().padLeft(3, '0')}  ${entry.source}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  Text(
                    entry.phase,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: canceled ? const Color(0xffb46c16) : _blue,
                    ),
                  ),
                  if (entry.position != null)
                    Text(
                      '位置 ${entry.position!.dx.toStringAsFixed(0)}, ${entry.position!.dy.toStringAsFixed(0)}${entry.taps > 0 ? ' · 连击 ${entry.taps}' : ''}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  if (entry.cancelReason != null)
                    Text(
                      entry.cancelReason!,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                ],
              );
            },
          ),
        ),
    ],
  );
}

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.number,
    required this.title,
    required this.description,
    required this.children,
  });

  final String number;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xffe5e9f0)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Text(
                number,
                style: const TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: _muted, height: 1.6),
          ),
          ...children,
        ],
      ),
    ),
  );
}

class _LogEntry {
  const _LogEntry(
    this.sequence,
    this.source,
    this.phase,
    this.position,
    this.taps,
    this.cancelReason,
  );

  final int sequence;
  final String source;
  final String phase;
  final Offset? position;
  final int taps;
  final String? cancelReason;
}

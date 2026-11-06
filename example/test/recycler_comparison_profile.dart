part of 'recycler_official_comparison_test.dart';

const _profile = bool.fromEnvironment('RECYCLER_COMPARE_PROFILE');
const _profileRender = bool.fromEnvironment('RECYCLER_COMPARE_PROFILE_RENDER');
const _phaseNames = [
  'BUILD',
  'LAYOUT',
  'PAINT',
  'SEMANTICS',
  'COMPOSITING_BITS',
  'COMPOSITING',
  'FINALIZE_TREE',
  'POST_FRAME',
];

class _ComparisonProfile {
  _ComparisonProfile(this.tester, this.connection, this.previousStreams)
    : previousLayouts = debugProfileLayoutsEnabled,
      previousPaints = debugProfilePaintsEnabled;

  final WidgetTester tester;
  final _VmConnection connection;
  final List<String> previousStreams;
  final bool previousLayouts, previousPaints;
  final windows = <_ProfileWindow>[];

  static Future<_ComparisonProfile> open(WidgetTester tester) async {
    final connection = (await tester.runAsync(_VmConnection.open))!;
    try {
      final flags = (await tester.runAsync(() => connection.rpc('getVMTimelineFlags')))!;
      final streams = (flags['recordedStreams']! as List).cast<String>();
      final result = _ComparisonProfile(tester, connection, streams);
      await result._rpc('setVMTimelineFlags', {
        'recordedStreams': ['Dart', 'GC'],
      });
      if (_profileRender) {
        debugProfileLayoutsEnabled = true;
        debugProfilePaintsEnabled = true;
      }
      return result;
    } catch (_) {
      await tester.runAsync(connection.close);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _rpc(String method, [Map<String, Object?>? params]) async =>
      (await tester.runAsync(() => connection.rpc(method, params)))!;

  Future<void> startLeg(int leg) async {
    windows.clear();
    await _rpc('clearVMTimeline');
  }

  _ProfileWindow beginFrame(int leg, int frame) {
    final window = _ProfileWindow(leg, frame);
    windows.add(window);
    return window;
  }

  Future<Map<String, Object?>> finishLeg(int leg) async {
    if (windows.length != _samplesPerLeg || windows.any((window) => window.end == null || window.leg != leg)) {
      throw StateError('Timeline 必须覆盖本段全部已结束的测量帧');
    }
    final start = windows.first.start;
    final end = windows.last.end!;
    final timeline = await _rpc('getVMTimeline', {'timeOriginMicros': start, 'timeExtentMicros': end - start});
    return _TimelineSummary(timeline, windows).toJson();
  }

  Future<void> close() async {
    debugProfileLayoutsEnabled = previousLayouts;
    debugProfilePaintsEnabled = previousPaints;
    try {
      await _rpc('setVMTimelineFlags', {'recordedStreams': previousStreams});
    } finally {
      await tester.runAsync(connection.close);
    }
  }
}

class _ProfileWindow {
  _ProfileWindow(this.leg, this.frame) {
    task.start('RECYCLER_COMPARE_FRAME.$leg.$frame');
    // Timeline.now 与 getVMTimeline 使用相同的单调时钟，不能用测试的虚拟帧时间筛选。
    start = developer.Timeline.now;
  }

  final int leg, frame;
  final task = developer.TimelineTask();
  late final int start;
  int? end;

  void finish() {
    end = developer.Timeline.now;
    task.finish();
  }
}

class _VmHttpOverrides extends HttpOverrides {}

class _VmConnection {
  _VmConnection(this.client, this.socket) : messages = StreamIterator(socket);

  final HttpClient client;
  final WebSocket socket;
  final StreamIterator<dynamic> messages;
  int sequence = 0;

  static Future<_VmConnection> open() async {
    final info = await developer.Service.getInfo();
    final base = info.serverUri;
    if (base == null) throw StateError('Timeline 诊断需要 flutter test --enable-vmservice，仅连接本测试进程');
    if (!['127.0.0.1', 'localhost', '::1'].contains(base.host)) {
      throw StateError('Timeline 诊断只允许连接本测试进程自己的本机 VM Service');
    }
    // Widget 测试默认返回假 HTTP 响应；只为本机 VM 的 WebSocket 创建真实客户端。
    final client = HttpOverrides.runWithHttpOverrides(() => HttpClient(), _VmHttpOverrides())
      ..connectionTimeout = Duration(seconds: 3);
    try {
      final uri = base.resolve('ws').replace(scheme: base.scheme == 'https' ? 'wss' : 'ws');
      final socket = await WebSocket.connect(uri.toString(), customClient: client).timeout(Duration(seconds: 5));
      return _VmConnection(client, socket);
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> rpc(String method, [Map<String, Object?>? params]) async {
    final id = ++sequence;
    socket.add(jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params ?? {}}));
    while (await messages.moveNext().timeout(Duration(seconds: 10))) {
      final response = jsonDecode(messages.current as String) as Map<String, dynamic>;
      if (response['id'] != id) continue;
      if (response['error'] != null) throw StateError('VM Service $method 失败：${response['error']}');
      return response['result']! as Map<String, dynamic>;
    }
    throw StateError('本测试进程的 VM Service 在 $method 返回前断开连接');
  }

  Future<void> close() async {
    try {
      await messages.cancel();
      await socket.close().timeout(Duration(seconds: 3));
    } finally {
      client.close(force: true);
    }
  }
}

typedef _Range = ({int start, int end});

class _Span {
  _Span(this.name, this.category, this.thread, this.start, this.end, this.order);
  final String name, category, thread;
  final int start, end, order;
  final children = <_Span>[];
  _Span? parent;

  _Range? clipped(int from, int to) {
    final left = math.max(start, from), right = math.min(end, to);
    return right > left ? (start: left, end: right) : null;
  }

  int selfUs(_Range range) =>
      range.end - range.start - _union([for (final child in children) ?child.clipped(range.start, range.end)]);
}

class _TimelineSummary {
  _TimelineSummary(this.timeline, this.windows) {
    _parse();
  }

  final Map<String, dynamic> timeline;
  final List<_ProfileWindow> windows;
  final spans = <_Span>[];
  int unmatchedEnds = 0, unmatchedBegins = 0, traceEvents = 0;

  void _parse() {
    final events = (timeline['traceEvents']! as List).whereType<Map>().indexed.toList()
      ..sort((a, b) {
        final byTime = _stamp(a.$2).compareTo(_stamp(b.$2));
        return byTime == 0 ? a.$1.compareTo(b.$1) : byTime;
      });
    traceEvents = events.length;
    final stacks = <String, List<(int, Map)>>{};
    for (final (order, event) in events) {
      final phase = event['ph'];
      final thread = '${event['pid']}/${event['tid']}';
      final stamp = _stamp(event);
      if (phase == 'B') {
        stacks.putIfAbsent(thread, () => []).add((order, event));
      } else if (phase == 'E') {
        final stack = stacks[thread];
        if (stack == null || stack.isEmpty) {
          unmatchedEnds++;
        } else {
          final (beginOrder, begin) = stack.removeLast();
          _add(begin, thread, _stamp(begin), stamp, beginOrder);
        }
      } else if (phase == 'X') {
        _add(event, thread, stamp, stamp + ((event['dur'] as num?)?.toInt() ?? 0), order);
      }
    }
    unmatchedBegins = stacks.values.fold(0, (sum, stack) => sum + stack.length);
    final threads = <String, List<_Span>>{};
    for (final span in spans) {
      threads.putIfAbsent(span.thread, () => []).add(span);
    }
    for (final thread in threads.values) {
      thread.sort((a, b) {
        final start = a.start.compareTo(b.start);
        if (start != 0) return start;
        final end = b.end.compareTo(a.end);
        return end == 0 ? a.order.compareTo(b.order) : end;
      });
      final stack = <_Span>[];
      for (final span in thread) {
        while (stack.isNotEmpty && (span.start >= stack.last.end || span.end > stack.last.end)) {
          stack.removeLast();
        }
        if (stack.isNotEmpty) {
          span.parent = stack.last;
          stack.last.children.add(span);
        }
        stack.add(span);
      }
    }
  }

  void _add(Map event, String thread, int start, int end, int order) {
    if (end < start) return;
    spans.add(_Span('${event['name'] ?? ''}', '${event['cat'] ?? ''}', thread, start, end, order));
  }

  Map<String, Object?> toJson() {
    final frames = <Map<String, Object?>>[];
    final named = <String, _EventTotals>{};
    final renders = <String, _EventTotals>{};
    final gcNames = <String, int>{};
    final exclusiveTotals = {for (final phase in _phaseNames) phase: 0};
    final phaseSamples = {for (final phase in _phaseNames) phase: <int>[]};
    final phaseCalls = {for (final phase in _phaseNames) phase: 0};
    var frameworkUnion = 0, unassigned = 0, gcUnion = 0;
    for (final window in windows) {
      final end = window.end!;
      final active = [
        for (final span in spans)
          if (span.clipped(window.start, end) != null) span,
      ];
      final phaseRanges = {for (final name in _phaseNames) name: <_Range>[]};
      final phases = <(String, _Range)>[];
      final gc = <_Range>[];
      final frameNamed = <String, _EventTotals>{};
      for (final span in active) {
        final range = span.clipped(window.start, end)!;
        final phase = _phase(span.name);
        if (phase != null) {
          phaseRanges[phase]!.add(range);
          phases.add((phase, range));
          phaseCalls[phase] = phaseCalls[phase]! + 1;
        }
        if (span.name.startsWith('RecyclerView.') || span.name.startsWith('Semantics.')) {
          named.putIfAbsent(span.name, _EventTotals.new).add(span, range);
          frameNamed.putIfAbsent(span.name, _EventTotals.new).add(span, range);
        }
        if (_isGc(span)) {
          gc.add(range);
          gcNames.update(span.name, (count) => count + 1, ifAbsent: () => 1);
        }
        if (_profileRender && span.name.contains('Render')) {
          final phase = _enclosingPhase(span);
          if (phase == 'LAYOUT' || phase == 'PAINT') {
            renders.putIfAbsent('$phase/${span.name}', _EventTotals.new).add(span, range);
          }
        }
      }
      final inclusive = {for (final phase in _phaseNames) phase: _union(phaseRanges[phase]!)};
      if (phaseRanges['LAYOUT']!.isEmpty) {
        throw StateError('Timeline 缺少第${window.frame}帧的 LAYOUT，不能把被截断或未录制的追踪作为阶段数据');
      }
      final exclusive = _partition(phases);
      for (final phase in _phaseNames) {
        phaseSamples[phase]!.add(inclusive[phase]!);
        exclusiveTotals[phase] = exclusiveTotals[phase]! + exclusive[phase]!;
      }
      final union = _union(phases.map((entry) => entry.$2).toList());
      final gcUs = _union(gc);
      final other = end - window.start - union;
      frameworkUnion += union;
      unassigned += other;
      gcUnion += gcUs;
      frames.add({
        'frame': window.frame,
        'start_us': window.start,
        'end_us': end,
        'window_wall_us': end - window.start,
        'phase_inclusive_union_us': inclusive,
        'phase_exclusive_partition_us': exclusive,
        'all_framework_phases_union_us': union,
        'outside_framework_phases_us': other,
        'gc_any_thread_overlap_union_us': gcUs,
        'selected_events': {for (final entry in frameNamed.entries) entry.key: entry.value.toJson()},
      });
    }
    final renderList = renders.entries.toList()..sort((a, b) => b.value.self.compareTo(a.value.self));
    return {
      'recorded_streams': ['Dart', 'GC'],
      'frame_count': windows.length,
      'trace_event_count': traceEvents,
      'synchronous_span_count': spans.length,
      'unmatched_begin_events': unmatchedBegins,
      'unmatched_end_events': unmatchedEnds,
      'clock': 'developer.Timeline.now; same monotonic microsecond clock as VM getVMTimeline',
      'aggregation': 'per-frame clipped interval unions; exclusive partition selects the innermost framework phase; nested BUILD belongs to BUILD rather than LAYOUT; selected/render inclusive sums are not additive',
      'gc_scope': 'GC stream events on any VM thread overlapping measured frame windows; parallel GC is not equivalent to a UI-thread pause',
      'render_scope': _profileRender
          ? 'debugProfileLayoutsEnabled/PaintsEnabled; layout events include cached RenderObject.layout calls, unlike row performLayout counters; top sorted by synchronous self time'
          : 'disabled; enable RECYCLER_COMPARE_PROFILE_RENDER with PROFILE for per-Render-type spans',
      'phases': {
        for (final phase in _phaseNames)
          phase: {
            'calls': phaseCalls[phase],
            'inclusive_union_us': phaseSamples[phase]!.fold(0, (sum, value) => sum + value),
            'exclusive_partition_us': exclusiveTotals[phase],
            'per_frame': _timings(phaseSamples[phase]!),
          },
      },
      'all_framework_phases_union_us': frameworkUnion,
      'outside_framework_phases_us': unassigned,
      'gc_any_thread_overlap_union_us': gcUnion,
      'gc_event_names': gcNames,
      'selected_events': {for (final entry in named.entries) entry.key: entry.value.toJson()},
      if (_profileRender)
        'top_render_events_by_self_us': [
          for (final entry in renderList.take(24)) {'phase_and_type': entry.key, ...entry.value.toJson()},
        ],
      'raw_frames': frames,
    };
  }
}

class _EventTotals {
  int calls = 0, inclusive = 0, self = 0;
  final ranges = <_Range>[];

  void add(_Span span, _Range range) {
    calls++;
    inclusive += range.end - range.start;
    self += span.selfUs(range);
    ranges.add(range);
  }

  Map<String, int> toJson() => {
    'calls': calls,
    'inclusive_sum_us': inclusive,
    'union_us': _union(ranges),
    'self_us': self,
  };
}

int _stamp(Map event) => (event['ts'] as num?)?.toInt() ?? 0;

String? _phase(String name) {
  if (name == 'BUILD') return 'BUILD';
  if (name == 'LAYOUT' || name == 'LAYOUT (root)') return 'LAYOUT';
  if (name == 'PAINT' || name == 'PAINT (root)') return 'PAINT';
  if (name == 'SEMANTICS' || name == 'SEMANTICS (root)') return 'SEMANTICS';
  if (name.startsWith('UPDATING COMPOSITING BITS')) return 'COMPOSITING_BITS';
  if (name == 'COMPOSITING') return 'COMPOSITING';
  if (name == 'FINALIZE TREE') return 'FINALIZE_TREE';
  if (name == 'POST_FRAME') return 'POST_FRAME';
  return null;
}

String? _enclosingPhase(_Span span) {
  var current = span.parent;
  while (current != null) {
    final phase = _phase(current.name);
    if (phase != null) return phase;
    current = current.parent;
  }
  return null;
}

bool _isGc(_Span span) =>
    span.category.split(',').any((category) => category.trim() == 'GC') ||
    span.name.startsWith('CollectNewGeneration') ||
    span.name.startsWith('CollectOldGeneration') ||
    span.name == 'GC';

int _union(List<_Range> ranges) {
  if (ranges.isEmpty) return 0;
  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  var start = sorted.first.start, end = sorted.first.end, total = 0;
  for (final range in sorted.skip(1)) {
    if (range.start > end) {
      total += end - start;
      start = range.start;
      end = range.end;
    } else {
      end = math.max(end, range.end);
    }
  }
  return total + end - start;
}

Map<String, int> _partition(List<(String, _Range)> phases) {
  final result = {for (final phase in _phaseNames) phase: 0};
  final points = {for (final entry in phases) entry.$2.start, for (final entry in phases) entry.$2.end}.toList()
    ..sort();
  for (var index = 1; index < points.length; index++) {
    final start = points[index - 1], end = points[index];
    (String, _Range)? innermost;
    for (final phase in phases) {
      if (phase.$2.start > start || phase.$2.end < end) continue;
      if (innermost == null || phase.$2.end - phase.$2.start < innermost.$2.end - innermost.$2.start) {
        innermost = phase;
      }
    }
    if (innermost != null) result[innermost.$1] = result[innermost.$1]! + end - start;
  }
  return result;
}

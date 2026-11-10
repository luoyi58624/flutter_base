import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../example_page.dart';
import 'comparison_list.dart';
import 'scroll_mode.dart';
import '../../../widgets/panel.dart';

/// 在相同内容和滚动轨迹上比较一次 UI 线程尖峰的影响。
class RecyclerSpikePage extends StatefulWidget {
  /// 创建尖峰示例，测试可替换注入工作而保留真实手势与调度。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerSpikePage({super.key, this.runWork});

  /// 在计划帧中执行一次指定时长的工作；默认忙等至该时长。
  final ValueChanged<Duration>? runWork;

  @override
  State<RecyclerSpikePage> createState() => _RecyclerSpikePageState();
}

enum _SpikePhase {
  drag('拖动中'),
  inertia('松手惯性'),
  script('脚本快滑');

  const _SpikePhase(this.label);
  final String label;
}

typedef _SpikeResult = ({SliverExampleMode mode, _SpikePhase phase, int targetMs, int actualUs});

const _itemCount = 10000;

double _rowExtent(BuildContext context) => 68 + math.max(0.0, MediaQuery.textScalerOf(context).scale(14) - 14) * 3;

class _RecyclerSpikePageState extends State<RecyclerSpikePage> {
  final _controller = ScrollController(keepScrollOffset: false);
  var _mode = SliverExampleMode.recycler;
  var _phase = _SpikePhase.drag;
  var _budget = 8;
  _SpikePhase? _armed;
  int? _pointer;
  bool _movedDuringTouch = false;
  Timer? _inertiaWindow;
  int? _callbackId;
  int _generation = 0;
  bool _scriptRunning = false;
  ({double origin, double triggerDistance})? _script;
  _SpikeResult? _result;

  ScrollPosition? get _position {
    final controller = _controller;
    return controller.positions.length == 1 ? controller.position : null;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_didScroll);
  }

  void _cancelInertiaWindow() {
    _inertiaWindow?.cancel();
    _inertiaWindow = null;
  }

  void _cancelWork() {
    _generation++;
    final callback = _callbackId;
    if (callback != null) SchedulerBinding.instance.cancelFrameCallbackWithId(callback);
    _callbackId = null;
    _armed = null;
    _script = null;
    _scriptRunning = false;
    _cancelInertiaWindow();
  }

  void _stop() {
    final wasRunning = _scriptRunning;
    setState(_cancelWork);
    if (_position case final position? when wasRunning) position.jumpTo(position.pixels);
  }

  void _changeMode(SliverExampleMode mode) {
    if (_mode == mode) return;
    _stop();
    setState(() {
      _pointer = null;
      _mode = mode;
    });
  }

  void _arm() {
    setState(() {
      _cancelWork();
      _armed = _phase;
      _result = null;
    });
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    if (_scriptRunning) _stop();
    _cancelInertiaWindow();
    _pointer = event.pointer;
    _movedDuringTouch = false;
  }

  void _up(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    if (_movedDuringTouch && _armed == .inertia) {
      // 只认紧随这次抬手的真实惯性位移，后续滚轮或脚本不能命中这个窗口。
      _inertiaWindow = Timer(Duration(milliseconds: 250), () => _inertiaWindow = null);
    }
  }

  void _cancelPointer(PointerCancelEvent event) {
    if (_pointer == event.pointer) _pointer = null;
    _cancelInertiaWindow();
  }

  void _didScroll() {
    final position = _position;
    if (position == null || !position.hasPixels) return;
    final pixels = position.pixels;
    if (_script case final script?) {
      if ((pixels - script.origin).abs() >= script.triggerDistance) {
        _script = null;
        _scheduleWork(.script, pixels);
      }
      return;
    }
    if (_pointer != null) {
      _movedDuringTouch = true;
      if (_armed == .drag) _scheduleWork(.drag, pixels);
    } else if (_armed == .inertia && _inertiaWindow != null && position.isScrollingNotifier.value) {
      _scheduleWork(.inertia, pixels);
    }
  }

  Future<void> _runScript() async {
    final position = _position;
    if (position == null || !position.haveDimensions) return;
    final origin = position.minScrollExtent;
    final distance = math.min(1800.0, position.maxScrollExtent - origin);
    if (distance <= 0) return;
    setState(() {
      _cancelWork();
      _scriptRunning = true;
      _result = null;
    });
    // 每次从同一批条目出发，比较容器时注入点和滚动距离也相同。
    if (position.pixels != origin) position.jumpTo(origin);
    _script = (origin: origin, triggerDistance: distance / 4);
    final generation = _generation;
    try {
      await position.animateTo(origin + distance, duration: Duration(milliseconds: 600), curve: Curves.linear);
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _script = null;
          _scriptRunning = false;
        });
      }
    }
  }

  void _scheduleWork(_SpikePhase phase, double pixels) {
    if (_callbackId != null) return;
    _armed = null;
    _cancelInertiaWindow();
    final generation = _generation;
    final target = _budget;
    final mode = _mode;
    final budget = Duration(milliseconds: target);
    final binding = SchedulerBinding.instance;
    // 在下一帧的 transient 回调里执行，UI / Raster / 实际呈现仍按各自指标记录。
    _callbackId = binding.scheduleFrameCallback((_) {
      _callbackId = null;
      if (!mounted || generation != _generation) return;
      final watch = Stopwatch()..start();
      developer.Timeline.timeSync(
        'RecyclerSpike.work',
        () => (widget.runWork ?? _burn)(budget),
        arguments: {'mode': mode.name, 'phase': phase.name, 'target_us': budget.inMicroseconds, 'scroll_px': pixels},
      );
      watch.stop();
      // 结果面板晚一帧更新，避免把它的重建混进注入帧。
      binding.addPostFrameCallback((_) {
        if (!mounted || generation != _generation) return;
        setState(() => _result = (mode: mode, phase: phase, targetMs: target, actualUs: watch.elapsedMicroseconds));
      });
    });
  }

  static void _burn(Duration duration) {
    final watch = Stopwatch()..start();
    while (watch.elapsedMicroseconds < duration.inMicroseconds) {}
  }

  @override
  void dispose() {
    _cancelWork();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _armed != null || _scriptRunning;
    final result = _result;
    return ExamplePage(
      title: '单帧尖峰压力',
      actions: [SliverComparisonModeMenu(mode: _mode, onChanged: _changeMode)],
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: .fromLTRB(12, 4, 12, 8),
              child: Column(
                crossAxisAlignment: .start,
                spacing: 4,
                children: [
                  Text('每次注入一次。脚本 600 ms 移动 1800 px，走到四分之一时安排尖峰。'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final ms in [4, 8, 12, 20])
                        ChoiceChip(
                          key: ValueKey('spike-budget-$ms'),
                          label: Text('$ms ms'),
                          selected: _budget == ms,
                          onSelected: busy ? null : (_) => setState(() => _budget = ms),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: .center,
                    children: [
                      DropdownButton<_SpikePhase>(
                        key: ValueKey('spike-phase'),
                        value: _phase,
                        items: [
                          for (final phase in [_SpikePhase.drag, _SpikePhase.inertia])
                            DropdownMenuItem(value: phase, child: Text(phase.label)),
                        ],
                        onChanged: busy ? null : (phase) => setState(() => _phase = phase!),
                      ),
                      FilledButton(key: ValueKey('spike-arm'), onPressed: busy ? null : _arm, child: Text('武装手势')),
                      OutlinedButton(
                        key: ValueKey('spike-script'),
                        onPressed: busy ? null : _runScript,
                        child: Text('脚本快滑'),
                      ),
                      if (busy) TextButton(onPressed: _stop, child: Text('取消')),
                    ],
                  ),
                  Text(
                    _scriptRunning
                        ? '脚本运行中'
                        : _armed != null
                        ? '已武装 · ${_armed!.label}'
                        : result != null
                        ? '${result.mode.label} · ${result.phase.label} · '
                              '目标 ${result.targetMs} ms，注入 ${(result.actualUs / 1000).toStringAsFixed(2)} ms'
                        : 'UI 与 Raster 帧耗时可在「帧耗时记录」中采集。',
                    key: ValueKey('spike-result'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Listener(
                onPointerDown: _down,
                onPointerUp: _up,
                onPointerCancel: _cancelPointer,
                onPointerSignal: (_) => _cancelInertiaWindow(),
                child: SliverComparisonList(
                  mode: _mode,
                  controller: _controller,

                  itemCount: _itemCount,

                  itemBuilder: (_, index) => _SpikeRow(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpikeRow extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _SpikeRow(this.index);
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final id = (index + 1).toString().padLeft(5, '0');
    return SizedBox(
      height: _rowExtent(context),
      child: Padding(
        padding: .fromLTRB(12, 3, 12, 3),
        child: ExamplePanel(
          style: ElStyle(borderRadius: .circular(12), backgroundColor: colors.surfaceContainer, padding: .all(8)),
          child: Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: colors.primaryContainer, child: Icon(Icons.timeline, size: 18)),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: .center,
                  crossAxisAlignment: .start,
                  children: [
                    Text('滚动采样 $id', maxLines: 1, overflow: .ellipsis),
                    Text('统一行高 · 逻辑像素', maxLines: 1, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

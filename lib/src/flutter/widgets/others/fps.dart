import 'dart:async';
import 'dart:math';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'base.dart';

/// 显示当前帧率的小部件。
///
/// 只负责渲染帧率文本本身：使用 [TextPainter] 自绘，不包裹、不定位任何
/// 内容，显示位置完全由使用方决定——放进 [Stack] 后用 [Positioned] 自行
/// 定位即可。
///
/// 显示期间使用 [Ticker] 持续请求帧，按实际帧间隔计算每秒 UI 帧率；
/// 不按显示器上报的刷新率封顶，也不等待引擎批量投递耗时数据。
/// 数字约每秒更新一次；隐藏、停用 TickerMode 或进入后台时停止采样。
/// 这里测量 Flutter UI 帧回调频率，不代表 GPU 完成或屏幕实际呈现次数。
///
/// 只做实时仪表盘；要**录制一段时间**并结算掉帧/卡顿报告用 [ElFpsRecorder]。
class ElFps extends StatelessWidget {
  const ElFps({super.key, this.show = true, this.color = Colors.green});

  /// 是否显示帧率
  final bool show;

  /// 帧率文本颜色
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: show ? _FpsText(color: color) : ElEmptyWidget.instance);
  }
}

/// 帧率文本绘制器：用 [TextPainter] 自绘帧率数字，不依赖任何布局组件。
///
/// 绘制尺寸由文本内容决定（[textSize]），配合 [CustomPaint.size] 使用即可
/// 让 [ElFps] 在任意定位环境下自适应文本大小。
class ElFpsPainter extends CustomPainter {
  ElFpsPainter({required this.fps, required this.color});

  /// 当前帧率值
  final int fps;

  /// 帧率文本颜色
  final Color color;

  /// 帧率文本样式（字号 20、加粗）
  TextStyle get textStyle => TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold);

  /// 按当前帧率文本测量的绘制尺寸
  Size get textSize {
    final painter = TextPainter(
      text: TextSpan(text: '$fps', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.size;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: '$fps', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    painter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(ElFpsPainter oldDelegate) => oldDelegate.fps != fps || oldDelegate.color != color;
}

class _FpsText extends StatefulWidget {
  const _FpsText({required this.color});

  final Color color;

  @override
  State<_FpsText> createState() => _FpsTextState();
}

/// 帧率统计核心（纯逻辑，与 widget/引擎解耦，可单元测试）。
///
/// 口径：**每跨过一个完整 1 秒窗口结算一次「该秒内真实渲染的帧数」**——
/// 数字每秒稳定跳一次，瞬时毛刺被整秒积分平滑（瞬时统计量会把真实的
/// 产帧不均原样怼到数字上，作为仪表盘无法阅读）。
///
/// 数据源是引擎 [FrameTiming] 的 vsync 时间戳：只统计真实产出的帧，
/// 静止页面不产帧即为 0；一律按时间戳落桶，与攒批投递的到达时机无关，
/// 不会出现「上一秒的帧挤进下一秒导致超过显示器刷新率」。
///
/// 桶锚定在流首帧，窗口为「锚定帧之后的整 1 秒」（锚定帧自身不计数，
/// 边界帧计入当前桶）：165Hz 稳定结算 165，2fps 稳定结算 2，无 fencepost
/// 偏差；跨过 2 个以上空桶视为断流，从当前帧重新锚定。
class ElFpsCounter {
  ElFpsCounter({this.bucketUs = 1000000});

  /// 结算窗口时长（µs），默认 1 秒
  final int bucketUs;

  /// 当前桶起点（流首帧时间戳），null = 未锚定
  int? _bucketStart;

  /// 当前桶内已计数的帧数
  int _count = 0;

  /// 已见过的最新时间戳，乱序/重复防御
  int _lastTs = -1;

  /// 喂入一批帧的 vsync 时间戳（µs）。跨过整秒边界时返回刚结算完的那
  /// 一秒的帧数，桶内累计阶段返回 null（调用方保持原显示）。
  int? addBatch(Iterable<int> vsyncTimestampsUs) {
    int? completed;
    for (final ts in vsyncTimestampsUs) {
      if (ts <= _lastTs) continue;
      _lastTs = ts;
      final start = _bucketStart;
      if (start == null) {
        _bucketStart = ts;
        _count = 0;
        continue;
      }
      if (ts - start <= bucketUs) {
        _count++;
      } else {
        completed = _count;
        if (ts - start >= 2 * bucketUs) {
          // 断流：中间隔着整个空桶，从当前帧重新锚定
          _bucketStart = ts;
          _count = 0;
        } else {
          _bucketStart = start + bucketUs;
          _count = 1;
        }
      }
    }
    return completed;
  }

  /// 清空状态（判定停帧后调用，下一段动画从新流重新锚定）。
  void reset() {
    _bucketStart = null;
    _count = 0;
    _lastTs = -1;
  }
}

class _FpsTextState extends State<_FpsText> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  int _fps = 0;
  int? _windowStartUs;
  int? _lastTimestampUs;
  int _frameCount = 0;
  bool _tickerModeEnabled = true;

  void _onTick(Duration _) {
    // 使用未经过 timeDilation 缩放的引擎时间；首帧只锚定，不凭平台猜测减一。
    final timestamp = SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    if (_lastTimestampUs != null && timestamp <= _lastTimestampUs!) return;
    _lastTimestampUs = timestamp;
    final start = _windowStartUs;
    if (start == null) {
      _windowStartUs = timestamp;
      return;
    }
    _frameCount++;
    final elapsed = timestamp - start;
    if (elapsed < 1000000) return;
    // 卡顿可能让窗口超过一秒，必须按实际时长归一化，不能直接把帧数当帧率。
    final value = (_frameCount * 1000000 / elapsed).round();
    _windowStartUs = timestamp;
    _frameCount = 0;
    if (value != _fps) setState(() => _fps = value);
  }

  void _syncTicker() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active = _tickerModeEnabled && (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (active == _ticker.isActive) return;
    _windowStartUs = null;
    _lastTimestampUs = null;
    _frameCount = 0;
    if (_fps != 0) setState(() => _fps = 0);
    if (active) {
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerModeEnabled = TickerMode.of(context);
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncTicker();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = ElFpsPainter(fps: _fps, color: widget.color);
    return RepaintBoundary(
      child: CustomPaint(size: painter.textSize, painter: painter),
    );
  }
}

/// 帧率录制器 —— [ElFps] 家族的「录一段时间、出一份报告」能力。
///
/// [ElFps] 只实时显示当前秒帧率，排查间歇性掉帧需要的是一段时间的完整帧
/// 流水。本类被动订阅引擎 [FrameTiming]，与 [ElFps] 的主动 UI 采样不同；
/// 使用 [ElFpsCounter] 结算 vsync 时间戳：录制期只追加时间戳
/// （零聚合成本，不干扰被测帧），[report] 时一次性结算出每秒帧率序列、
/// 平均帧率、掉帧/卡顿次数与最坏帧间隔。
///
/// 喂入方式二选一：
/// - 真机：[attach] 订阅引擎 [FrameTiming]，采够一段时间后 [detach] +
///   [report]；或一步到位 `await ElFpsRecorder.record(Duration(seconds: 10))`。
/// - 测试/离线：[addFrames] 直接喂时间戳（µs）。widget 测试没有引擎产帧，
///   用逐帧 CPU 墙钟合成的 vsync 时间轴喂入即可复用同一套结算口径。
class ElFpsRecorder {
  ElFpsRecorder({this.expectedRefreshRate});

  /// 期望刷新率（Hz）。null 时结算期用帧间隔中位数推断——「多数帧正常、
  /// 少数帧掉帧」的间歇性场景里，中位间隔就是真实 vsync 间隔。
  final double? expectedRefreshRate;

  final List<int> _timestampsUs = <int>[];

  TimingsCallback? _timingsCallback;

  /// 已录制的帧数。
  int get frameCount => _timestampsUs.length;

  /// 直接喂入一批帧时间戳（µs）。乱序/重复时间戳自动丢弃，与 [ElFpsCounter]
  /// 同款防御。
  void addFrames(Iterable<int> vsyncTimestampsUs) {
    for (final ts in vsyncTimestampsUs) {
      if (_timestampsUs.isNotEmpty && ts <= _timestampsUs.last) continue;
      _timestampsUs.add(ts);
    }
  }

  /// 订阅引擎 [FrameTiming] 开始录制；重复调用无副作用。
  void attach() {
    if (_timingsCallback != null) return;
    final callback = _onTimings;
    _timingsCallback = callback;
    SchedulerBinding.instance.addTimingsCallback(callback);
  }

  /// 停止录制。已录数据保留，仍可 [report]。
  void detach() {
    final callback = _timingsCallback;
    if (callback == null) return;
    _timingsCallback = null;
    SchedulerBinding.instance.removeTimingsCallback(callback);
  }

  /// 清空已录数据；订阅状态不变，可原地开启下一段录制。
  void reset() => _timestampsUs.clear();

  /// 结算当前已录数据的报告；不清空数据，可续录后再出新报告。
  ElFpsReport report() => ElFpsReport.fromTimestamps(_timestampsUs, expectedRefreshRate: expectedRefreshRate);

  void _onTimings(List<FrameTiming> timings) {
    addFrames([for (final timing in timings) timing.timestampInMicroseconds(FramePhase.vsyncStart)]);
  }

  /// 录制 [duration] 时长并直接返回报告（真机一步到位用法）。
  static Future<ElFpsReport> record(Duration duration, {double? expectedRefreshRate}) async {
    final recorder = ElFpsRecorder(expectedRefreshRate: expectedRefreshRate)..attach();
    await Future<void>.delayed(duration);
    recorder.detach();
    return recorder.report();
  }
}

/// 一段录制期的帧率报告。
///
/// 掉帧口径：以期望刷新间隔为槽宽，一个帧间隔占了 n 个槽即掉了 n-1 帧
/// （120Hz 下 16.7ms 的间隔 = 错过 1 个 vsync = 掉 1 帧）；间隔超过期望
/// 间隔 1.5 倍记一次卡顿。「间歇性掉帧」的典型形态：[secondRates] 大体
/// 贴满刷新率、周期性矮一截，[droppedFrames] 与 [jankFrames] 同量级。
final class ElFpsReport {
  /// 直接构造（通常用 [ElFpsReport.fromTimestamps]）。
  const ElFpsReport({
    required this.frameCount,
    required this.elapsed,
    required this.averageFps,
    required this.refreshRate,
    required this.secondRates,
    required this.droppedFrames,
    required this.jankFrames,
    required this.worstInterval,
  });

  /// 从 vsync 时间戳序列（µs，需单调递增）结算报告。
  factory ElFpsReport.fromTimestamps(List<int> timestampsUs, {double? expectedRefreshRate}) {
    if (timestampsUs.length < 2) {
      return ElFpsReport(
        frameCount: timestampsUs.length,
        elapsed: Duration.zero,
        averageFps: 0,
        refreshRate: expectedRefreshRate ?? 0,
        secondRates: const <int>[],
        droppedFrames: 0,
        jankFrames: 0,
        worstInterval: Duration.zero,
      );
    }
    final intervals = <int>[for (var i = 1; i < timestampsUs.length; i++) timestampsUs[i] - timestampsUs[i - 1]];
    final elapsedUs = timestampsUs.last - timestampsUs.first;
    final sorted = [...intervals]..sort();
    final medianUs = sorted[sorted.length ~/ 2];
    final refreshRate = expectedRefreshRate ?? (medianUs <= 0 ? 0 : 1e6 / medianUs);
    final expectedUs = refreshRate <= 0 ? 0.0 : 1e6 / refreshRate;
    var dropped = 0;
    var jank = 0;
    var worstUs = 0;
    for (final interval in intervals) {
      if (interval > worstUs) worstUs = interval;
      if (expectedUs <= 0) continue;
      final missed = (interval / expectedUs).round() - 1;
      if (missed > 0) dropped += missed;
      if (interval > expectedUs * 1.5) jank++;
    }
    // 每秒帧率序列：逐帧喂 ElFpsCounter，收集每次跨过整秒边界的结算值
    //（整批 addBatch 跨多秒时中间桶会被覆盖，必须逐帧收集）。
    final counter = ElFpsCounter();
    final rates = <int>[];
    for (final ts in timestampsUs) {
      final rate = counter.addBatch([ts]);
      if (rate != null) rates.add(rate);
    }
    return ElFpsReport(
      frameCount: timestampsUs.length,
      elapsed: Duration(microseconds: elapsedUs),
      averageFps: intervals.length * 1e6 / elapsedUs,
      refreshRate: refreshRate,
      secondRates: List<int>.unmodifiable(rates),
      droppedFrames: dropped,
      jankFrames: jank,
      worstInterval: Duration(microseconds: worstUs),
    );
  }

  /// 录制帧数。
  final int frameCount;

  /// 首帧到末帧的时长。
  final Duration elapsed;

  /// 平均帧率（帧间隔口径：间隔数 / 总时长）。
  final double averageFps;

  /// 结算口径的刷新率（外部指定或中位间隔推断）。
  final double refreshRate;

  /// 每秒帧率序列（整秒落桶，口径同 [ElFpsCounter]；不足 1 秒为空）。
  final List<int> secondRates;

  /// 掉帧总数（错过的 vsync 槽数）。
  final int droppedFrames;

  /// 卡顿次数（帧间隔 > 1.5 × 期望间隔的次数）。
  final int jankFrames;

  /// 最坏一次帧间隔。
  final Duration worstInterval;

  /// 每秒帧率最小值（不足 1 秒时为 0）。
  int get minSecondFps => secondRates.isEmpty ? 0 : secondRates.reduce(min);

  /// 每秒帧率最大值（不足 1 秒时为 0）。
  int get maxSecondFps => secondRates.isEmpty ? 0 : secondRates.reduce(max);

  @override
  String toString() {
    final seconds = secondRates.isEmpty ? '' : ' | 每秒 $secondRates';
    return 'avg ${averageFps.toStringAsFixed(1)}fps @${refreshRate.toStringAsFixed(0)}Hz'
        '$seconds | 掉帧 $droppedFrames · 卡顿 $jankFrames'
        ' · 最坏 ${(worstInterval.inMicroseconds / 1000).toStringAsFixed(1)}ms'
        ' | $frameCount帧/${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
}

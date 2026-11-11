import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/widgets.dart' show TickerModeData;

import '../../../../utils/internal/bit_mask.dart';
import '../cascade/style_spec.dart';
import '../internal/field_spec.dart';
import '../resolved/resolved_style.dart';
import '../style.dart';
import 'frame_clock.dart';

/// 字段轨道上的一个显式停靠点。
typedef _TrackStop = (double offset, Object? value);

/// 每条 [ElAnimation] 声明的运行时时钟 + 预编译轨道。
class _KeyframeClock {
  _KeyframeClock(this.anim);

  /// 当前声明（timing 参数可被 [KeyframeRunner.sync] 原地更新，keyframes
  /// 变化则整个 clock 重建）。
  ElAnimation anim;

  /// 累计已过时间（paused 期冻结）。
  Duration elapsed = Duration.zero;

  /// 逐字段轨道：field → 按 offset 升序的显式停靠点表。keyframes 不变则终身复用。
  late final Map<ElTransitionField, List<_TrackStop>> tracks = _buildTracks(anim.keyframes);

  /// 本 clock 覆盖的字段位图。
  late final FieldMask fieldMask = fieldsMask(tracks.keys);

  /// 是否还需要推进时钟（无限循环 / 未播完 / delay 未结束；paused 不需要）。
  bool get needsTicking {
    if (anim.animationPlayState) return false;
    if (anim.animationIterationCount.isInfinite) return true;
    final total = anim.animationDelay + anim.animationDuration * anim.animationIterationCount;
    return elapsed < total;
  }

  /// 本帧施加的方向进度；delay 与结束区间按 fill 决定，null 表示回落声明值。
  double? sampleProgress() {
    final delay = anim.animationDelay;
    if (elapsed < delay) {
      return switch (anim.animationFillMode) {
        ElAnimationFillMode.backwards || ElAnimationFillMode.both => _mapDirection(0, 0),
        _ => null,
      };
    }
    final durationUs = anim.animationDuration.inMicroseconds;
    final count = anim.animationIterationCount;
    // duration 0 或 count 0 → active 相位不存在，直接结束态。
    final activeUs = durationUs * count;
    final tUs = (elapsed - delay).inMicroseconds;
    if (durationUs == 0 || count == 0 || (!count.isInfinite && tUs >= activeUs)) {
      final end = _endProgress();
      return switch (anim.animationFillMode) {
        ElAnimationFillMode.forwards || ElAnimationFillMode.both => end,
        _ => null,
      };
    }
    var iter = tUs ~/ durationUs;
    // 有限次数下钳制到最后一次迭代（tUs == activeUs 边界已被上方拦截）。
    if (!count.isInfinite) {
      final maxIter = (count == count.floorToDouble()) ? count.toInt() - 1 : count.floor();
      if (iter > maxIter) iter = maxIter;
    }
    final p = (tUs - iter * durationUs) / durationUs;
    return _mapDirection(p, iter);
  }

  /// 播完后的末帧进度（最后一次迭代的终点，按 direction 映射；小数次数取
  /// 最后一段部分迭代的终点）。
  double _endProgress() {
    final count = anim.animationIterationCount;
    if (count == 0) return _mapDirection(0, 0);
    final lastIter = (count == count.floorToDouble()) ? count.toInt() - 1 : count.floor();
    final endP = (count - lastIter).clamp(0.0, 1.0);
    return _mapDirection(endP, lastIter);
  }

  double _mapDirection(double p, int iteration) {
    final reversed = switch (anim.animationDirection) {
      ElAnimationDirection.normal => false,
      ElAnimationDirection.reverse => true,
      ElAnimationDirection.alternate => iteration.isOdd,
      ElAnimationDirection.alternateReverse => iteration.isEven,
    };
    return reversed ? 1 - p : p;
  }

  static Map<ElTransitionField, List<_TrackStop>> _buildTracks(Map<int, ElStyle> keyframes) {
    final percents = keyframes.keys.toList(growable: false)..sort();
    final tracks = <ElTransitionField, List<_TrackStop>>{};
    for (final percent in percents) {
      assert(percent >= 0 && percent <= 100, 'keyframe offset 百分比必须在 0..100：$percent');
      validateStyleConfiguration(keyframes[percent]!, variant: true);
      for (final entry in specOf(keyframes[percent]!).values.entries) {
        (tracks[entry.key] ??= <_TrackStop>[]).add((percent / 100, entry.value));
      }
    }
    return tracks;
  }
}

/// per-node 关键帧动画运行时（[ElRenderView] 持有，CSS animations 等价）。
class KeyframeRunner {
  /// 创建。[onTick] 在每帧推进后触发（宿主在回调里采样 + patch committed）。
  KeyframeRunner({required this.onTick, TickerModeData tickerMode = TickerModeData.fallback})
    : _tickerMode = tickerMode;

  /// 每帧回调。
  final void Function() onTick;

  final List<_KeyframeClock> _clocks = <_KeyframeClock>[];

  /// 上一次 [sample] 施加过的字段位图——本次未覆盖的差集字段需要回写 base
  /// （动画结束 / 声明移除的「摘除」语义）。
  FieldMask _lastAppliedMask = FieldMask.empty;

  ElAnimationClock? _clock;
  TickerModeData _tickerMode;
  bool _disposed = false;

  /// 同步宿主的 TickerMode，隐藏时保留关键帧相位而不请求新帧。
  set tickerMode(TickerModeData value) {
    _tickerMode = value;
    _clock?.tickerMode = value;
  }

  /// 当前全部时钟覆盖的字段位图 ∪ 上次施加位图（cascade 钉住掩码：正在动或
  /// 刚摘除还没回写的字段都不许被普通 cascade 接管）。
  FieldMask get activeFieldsMask {
    var m = _lastAppliedMask;
    for (final clock in _clocks) {
      m = maskOr(m, clock.fieldMask);
    }
    return m;
  }

  /// 是否存在声明（含已播完但 fill 仍生效的）。
  bool get hasClocks => _clocks.isNotEmpty;

  /// 对齐声明表（宿主每次 cascade 调用）。
  ///
  /// 匹配规则（对齐 CSS animation-name 语义，keyframes 表 ≈ name）：按列表
  /// index 对位，keyframes 相等 → 同一动画，timing 参数原地更新、时钟不重启；
  /// keyframes 变化 → 视为换了动画，从头播。表长缩短的尾部时钟丢弃（CSS 移除
  /// animation-name 即取消，字段回 base 由下次 [sample] 的差集回写完成）。
  void sync(List<ElAnimation> animations) {
    assert(!_disposed, 'sync after dispose');
    for (var i = 0; i < animations.length; i++) {
      final decl = animations[i];
      if (i < _clocks.length) {
        final clock = _clocks[i];
        if (ElAnimation.keyframesEqual(clock.anim.keyframes, decl.keyframes)) {
          clock.anim = decl;
          continue;
        }
        _clocks[i] = _KeyframeClock(decl);
      } else {
        _clocks.add(_KeyframeClock(decl));
      }
    }
    if (_clocks.length > animations.length) {
      _clocks.removeRange(animations.length, _clocks.length);
    }
    _syncTicking();
  }

  /// 以 [base]（不含动画覆盖的干净 target）为基值采样当前帧的字段覆盖表。
  ///
  /// 返回表包含：当前施加的动画字段值 + 上次施加但本次已摘除字段的 base 回写
  /// （调用方经 `CascadeTick.writeFieldsFromAnimation` diff-safe 落 committed）。

  Map<ElTransitionField, Object?> sample(ResolvedStyle base) {
    final values = <ElTransitionField, Object?>{};
    var appliedMask = FieldMask.empty;
    for (final clock in _clocks) {
      final progress = clock.sampleProgress();
      if (progress == null) continue;
      for (final entry in clock.tracks.entries) {
        final field = entry.key;
        values[field] = _sampleTrack(
          field: field,
          stops: entry.value,
          progress: progress,
          curve: clock.anim.animationTimingFunction,
          base: base,
        );
        appliedMask = maskSetBit(appliedMask, field.index);
      }
    }
    // 摘除差集：上次施加、本次没施加 → 回写 base 值（动画结束 fill none /
    // 声明被移除，字段回落 cascade 基值）。
    var removed = maskAndNot(_lastAppliedMask, appliedMask);
    while (removed.isNotEmpty) {
      final idx = maskLowestIndex(removed);
      removed = maskClearBit(removed, idx);
      final field = ElTransitionField.values[idx];
      values[field] = fieldSpecOf(field).read(base);
    }
    _lastAppliedMask = appliedMask;
    return values;
  }

  /// 单字段轨道采样：定位 [progress] 所在段，段内 curve 缓动后 lerp。
  Object? _sampleTrack({
    required ElTransitionField field,
    required List<_TrackStop> stops,
    required double progress,
    required Curve curve,
    required ResolvedStyle base,
  }) {
    final spec = fieldSpecOf(field);
    // 隐式端点（CSS implicit keyframe）：progress 落在首停靠点前 / 末停靠点后
    // 时，缺失侧以 base 值补位。
    var index = 0;
    while (index < stops.length && stops[index].$1 <= progress) {
      index++;
    }
    final from = index == 0 ? null : stops[index - 1];
    final to = index == stops.length ? null : stops[index];
    final fromOffset = from?.$1 ?? 0.0;
    final toOffset = to?.$1 ?? 1.0;
    final fromValue = from == null ? spec.read(base) : from.$2;
    if (fromOffset >= toOffset) return fromValue;
    final localT = ((progress - fromOffset) / (toOffset - fromOffset)).clamp(0.0, 1.0);
    return spec.lerp(fromValue, to == null ? spec.read(base) : to.$2, curve.transform(localT));
  }

  /// detach 语义：时钟清零 + 停表（CSS 元素移出文档；重挂载后 [sync] 重建
  /// 时钟从头播）。[_lastAppliedMask] 一并清零——committed 会随重挂载重建。
  void reset() {
    _clocks.clear();
    _lastAppliedMask = FieldMask.empty;
    _clock?.stop();
  }

  /// 释放资源。
  void dispose() {
    _disposed = true;
    _clock?.dispose();
    _clock = null;
    _clocks.clear();
  }

  void _syncTicking() {
    if (_clocks.any((clock) => clock.needsTicking)) {
      (_clock ??= ElAnimationClock(_tick, tickerMode: _tickerMode)).start();
    } else {
      _clock?.stop();
    }
  }

  void _tick(Duration dt) {
    for (final clock in _clocks) {
      if (!clock.needsTicking) continue;
      clock.elapsed += dt;
    }
    onTick();
    // 推进后可能全部播完 / 暂停：最后这次 onTick 已把 fill 终态（或摘除回写）
    // 采样出去，停表即可。
    _syncTicking();
  }
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show clampDouble, precisionErrorTolerance;
import 'package:flutter/widgets.dart';

/// 触摸连甩加速(Chrome FlingBooster)能力面。
///
/// physics 链上任一节点实现本接口,El 滚动视图的拖拽层即启用 Chromium
/// `ui/events/blink/fling_booster.cc` 语义:按下取消 fling 时**记住其起始
/// 速度**;此后手指保持同向、速度 ≥ [boostMinScrollVelocity] 的滑动会持续
/// 续期一个 [boostTimeout] 的窗口;窗口内松手成甩(现存 fling 中断时刻的
/// 速度与新手势速度都 ≥ [boostMinVelocity])→ 新 fling 起始速度 =
/// [combineBoostedVelocity](新手势, 前一 fling **起始**速度)——连甩等差
/// 累积无上限,配合样条距离 ∝ v^1.74 超线性放大,即 Chrome 连甩火箭感。
///
/// 之所以不用官方 [ScrollPhysics.carriedMomentum] 路径:官方
/// [ScrollDragController] 的叠加门是"新手势速度 > 0.5×携带速度",单手势又被
/// [ScrollPhysics.maxFlingVelocity] clamp——累计一旦超过 2×单手势上限,任何
/// 新甩都过不了门,动量整体丢弃、速度塌回单手势水平;且官方携带的是 hold
/// 时刻的**衰减后**速度而非起始速度,连甩收敛不到 Chrome 的等差累积。
/// [ElBrowserScrollPhysics] 的单手势速度上限默认值(逻辑像素/秒)。
///
/// 官方 [kMaxFlingVelocity] 是 8000(Android GestureDetector 口径),真机单次
/// 用力快甩轻易越过它、被手势层截顶,首甩起飞速度上不去;取其 2 倍放开
/// (用户真机裁决 2026-07-26)。连甩叠加仍在此之上无上限累积。
const double elBrowserMaxFlingVelocity = 16000.0;

/// [ElBrowserScrollPhysics] 的单次 fling 时长上限默认值。
///
/// 4s 这个数来自真机实测(2026-07-26 录屏逐帧分析):Android 厂商 ROM 的
/// 动态刷新率策略在**离手约 4.7s 后**把屏幕从 120Hz 降到 60Hz(录屏帧间隔
/// 从 8.3ms 整拍切到 16.6ms、锁死不抖,同期 UI/raster 耗时仍 <8.3ms——降的是
/// vsync 不是算力)。boost 连甩叠加后 v₀ 可达 4-5 万 px/s、样条自然时长 9s+,
/// 尾段必然滑进降档窗口,肉眼即"收尾掉到 60 帧"。把时长压在窗口内即规避。
///
/// 留 0.7s 余量取 4s 的副作用极小:单手势上限 16000px/s 的自然时长 4.28s,
/// 只被压掉 6% 距离(手感无差);受影响的只有连甩叠加出的超长尾巴。
const Duration elBrowserMaxFlingDuration = Duration(milliseconds: 4000);

abstract interface class ElFlingBoostSpec {
  /// 参与叠加的最低 fling 速度,现有 fling 与新手势各自都要过此门
  /// (官方 `kMinBoostFlingSpeedSquare` = 350²)。
  double get boostMinVelocity;

  /// 延迟取消期间维持 fling 存活所需的最低手指滚动速度
  /// (官方 `kMinBoostTouchScrollSpeedSquare` = 150²)。
  double get boostMinScrollVelocity;

  /// 延迟取消的静止窗口:超过该时长无达标移动即执行取消
  /// (官方 `kFlingBoostTimeoutDelay` = 50ms)。
  Duration get boostTimeout;

  /// 连甩叠加系数(官方全额 = 1.0)。
  double get boostFactor;

  /// 叠加后速度绝对上限(官方无上限 = infinity)。
  double get boostCap;

  /// 叠加公式:返回新 fling 的起始速度。两参数同在手势速度空间且已判同向。
  double combineBoostedVelocity(double gestureVelocity, double previousFlingVelocity);

  /// 由起始速度推算 fling 进行 [elapsedSeconds] 后的当前速度(带符号,
  /// 已结束返回 0)。拖拽层用它判定"fling 仍够快可 boost/延迟取消"。
  double flingVelocityAt({required double startVelocity, required double elapsedSeconds});
}

/// Chrome 移动端滚动物理:Android OverScroller 样条 fling 的逐常量移植
/// (Chromium `ui/events/mobile_scroller.cc` 同源)+ FlingBooster 连甩加速。
///
/// **模型来源**(2026-07 源码核实):Chrome 在 Android 上的触摸 fling 就是
/// Android 原生 OverScroller 的移植,不是"比 Android 尾巴更长的指数曲线":
/// - `kDefaultFriction = 0.015`(ViewConfiguration.getScrollFriction);
/// - `kInflexion = 0.35`、`kDecelerationRate = ln0.78/ln0.9 ≈ 2.3582`;
/// - 物理系数 `9.80665 × 39.37 × 160 × 0.84`(logical px 口径,与官方
///   [ClampingScrollSimulation] 同值);
/// - 距离 `D = f·c·exp(rate/(rate-1)·l)`、时长 `T = exp(l/(rate-1))`,
///   其中 `l = ln(inflexion·|v|/(f·c))`;
/// - 位置曲线 = 100 采样二分法预构建的三次贝塞尔样条查表 + 线性插值。
///
/// 与官方 [ClampingScrollPhysics]([ClampingScrollSimulation])的差别只在
/// **曲线形状与时长**:Flutter 为满足弹道重启协议把时长缩短到 rate×inflexion
/// ≈ 0.8254 倍并改用幂律近似;本类保留 Android 原样条——总距离两者完全相等,
/// 但真样条半程已覆盖 ~85.8% 距离(幂律 80.5%)、尾段以更低速度多爬 ~21% 时长,
/// 即"Chrome/原生 Android 手感"的爬行尾。代价:样条非无记忆曲线,fling 中途
/// goBallistic 重启(视口/内容尺寸变化)会以当前速度重开一条新样条、尾段
/// 略缩短——Android 原生 re-fling 同为此行为。
///
/// **连甩 boost** 对齐 Chrome FlingBooster(`ui/events/blink/fling_booster.cc`),
/// 经 [ElFlingBoostSpec] 由 El 拖拽层消费:按下停住 fling 时记住其**起始**
/// 速度,快速同向再甩(窗口/门槛见接口文档)则起飞速度等差全额叠加,无上限。
/// **不走**官方 [ScrollPhysics.carriedMomentum] 路径——官方
/// [ScrollDragController] 的叠加门是"新手势 > 0.5×携带速度",单手势又被
/// [maxFlingVelocity] clamp:累计一旦超过 2×单手势上限,任何新甩都过不了门,
/// 动量整体丢弃、速度塌回单手势水平;且官方携带的是衰减后速度,连甩收敛
/// 不到 Chrome 的等差累积。本类的 [carriedMomentum] 仅作官方 Scrollable
/// 宿主下的降级路径(El 拖拽层不调用它,不会双重叠加)。
///
/// **单手势速度上限** = [elBrowserMaxFlingVelocity](16000,官方
/// [kMaxFlingVelocity] 的 2 倍;用户裁决 2026-07-26:8000 把单次用力快甩截顶,
/// 首甩起飞速度不该被手势层拦腰砍)。再往上靠 boost 叠加达成——El 拖拽层在
/// 手势层 clamp **之后**叠加,官方 `drag.end → goBallistic` 直传速度不再
/// clamp,累积得以突破单手势上限,与 Chrome 结构一致。
///
/// **时长上限** = [maxFlingDuration](默认 4s)。连甩叠加能把 v₀ 推到 4-5 万
/// px/s、样条自然时长 9s+,而 Android ROM 的动态刷新率在离手 ~4.7s 后降到
/// 60Hz(真机录屏逐帧实测,2026-07-26),尾段必然滑进降档窗口。超限按恒等式
/// `D = inflexion·|v₀|·T` 反解距离(等价于按速度调高 friction),初速与终点
/// 归零都不受影响;传 [Duration.zero] 可退回纯官方样条时长。
///
/// **边界不归本类**:本类只定义**增量速度**(样条 fling + 连甩叠加),边界条件
/// 与越界回弹全部交给父链 [parent]——被谁包裹就随谁的边界,包
/// [ClampingScrollPhysics] 是硬停、包 [BouncingScrollPhysics] 是 rubber-band。
/// 父链尾部若无边界物理,[applyTo] 兜底补一节 clamping,standalone 用法与
/// 既有"硬边界停 + 父级 spring 回弹"口径一致。
class ElBrowserScrollPhysics extends ScrollPhysics implements ElFlingBoostSpec {
  /// 用官方同源默认参数创建;所有参数默认值即 Chrome 移动端口径。
  const ElBrowserScrollPhysics({
    this.friction = 0.015,
    double? maxFlingVelocity,
    this.maxFlingDuration = elBrowserMaxFlingDuration,
    this.boostFactor = 1.0,
    double? boostCap,
    this.boostMinVelocity = 350.0,
    super.parent,
    // ignore: prefer_initializing_formals
  }) : _maxFlingVelocity = maxFlingVelocity,
       // ignore: prefer_initializing_formals
       _boostCap = boostCap;

  /// fling 摩擦(官方 ViewConfiguration.getScrollFriction() = 0.015)。
  /// 越大减速越快、fling 越短。
  final double friction;

  /// 单次 fling 的时长上限;[Duration.zero] 或负值 = 不限(纯官方样条时长)。
  ///
  /// 超限时**按时长反解距离**而非硬切曲线:样条恒等式 `D = inflexion·|v₀|·T`
  /// (0.35·v·T,已数值验证逐速度精确成立)让"压时长"与"按该速度调高 friction"
  /// 完全等价——归一化速度形状、`dx(0) = v₀` 的初速连续性、单调衰减、终点
  /// 速度归零全部保持,只是整条曲线更陡。硬 clamp 时间(到点即停)会在尾段
  /// 留下非零速度突然归零的顿感,不采用。
  ///
  /// 默认 [elBrowserMaxFlingDuration](4s)= 规避 ROM 高刷保持窗口到期后的
  /// 60Hz 降档(见该常量文档)。
  final Duration maxFlingDuration;

  /// 连甩叠加系数。官方 FlingBooster 全额叠加(`velocity +=
  /// previous_fling_starting_velocity`)= 1.0。
  @override
  final double boostFactor;

  /// 现有 fling 速度低于此值不 boost(官方 kMinBoostFlingSpeed = 350 px/s,
  /// 来自 `kMinBoostFlingSpeedSquare = 350·350`)。
  @override
  final double boostMinVelocity;

  final double? _maxFlingVelocity;
  final double? _boostCap;

  @override
  ElBrowserScrollPhysics applyTo(ScrollPhysics? ancestor) {
    // 边界由父链决定（见类文档），本类不再自带边界条件；父链尾部兜底补一节
    // clamping，免得"没有祖先 / 祖先链里没有边界物理"时越界既不夹紧也不阻尼，
    // 内容能被直接拽出内容区。
    final chain = buildParent(ancestor ?? const ClampingScrollPhysics())!;
    return ElBrowserScrollPhysics(
      friction: friction,
      maxFlingVelocity: _maxFlingVelocity,
      maxFlingDuration: maxFlingDuration,
      boostFactor: boostFactor,
      boostCap: _boostCap,
      boostMinVelocity: boostMinVelocity,
      parent: chain is ClampingScrollPhysics ? chain : chain.applyTo(const ClampingScrollPhysics()),
    );
  }

  /// 单手势速度上限;null(默认)= [elBrowserMaxFlingVelocity](16000),
  /// **不**沿父链落到官方 8000。
  @override
  double get maxFlingVelocity => _maxFlingVelocity ?? elBrowserMaxFlingVelocity;

  /// boost 叠加上限;null(默认)= 无上限(官方 FlingBooster 不设 cap)。
  @override
  double get boostCap => _boostCap ?? double.infinity;

  /// 官方 carried momentum 路径的**降级**叠加(官方 Scrollable 宿主用):
  /// hold 时携带当前衰减速度,受官方 [ScrollDragController] 的"新手势 >
  /// 0.5×携带"比例门约束——累计超过 2×单手势上限后动量整体丢弃,无法复现
  /// Chrome 连甩;El 视图内由拖拽层 booster 按 [ElFlingBoostSpec] 接管
  /// (延迟取消跳过 hold,本方法收到的恒为 0,天然不双重叠加)。
  @override
  double carriedMomentum(double existingVelocity) {
    if (existingVelocity.abs() < boostMinVelocity) return 0.0;
    return existingVelocity.sign * math.min(existingVelocity.abs() * boostFactor, boostCap);
  }

  /// 官方 kMinBoostTouchScrollSpeed = 150 px/s。
  @override
  double get boostMinScrollVelocity => 150.0;

  /// 官方 kFlingBoostTimeoutDelay = 50ms。
  @override
  Duration get boostTimeout => const Duration(milliseconds: 50);

  /// 官方 `velocity += previous_fling_starting_velocity`(全额等差叠加)。
  @override
  double combineBoostedVelocity(double gestureVelocity, double previousFlingVelocity) {
    final combined = gestureVelocity + previousFlingVelocity * boostFactor;
    return combined.sign * math.min(combined.abs(), boostCap);
  }

  /// 样条速度曲线的解析采样:起始速度定 T 与 D,当前速度 = 速度系数·D/T。
  @override
  double flingVelocityAt({required double startVelocity, required double elapsedSeconds}) {
    if (startVelocity.abs() < precisionErrorTolerance) return 0.0;
    final sim = _SplineFlingSimulation(
      position: 0.0,
      velocity: startVelocity,
      friction: friction,
      maxDuration: maxFlingDuration,
    );
    if (sim.isDone(elapsedSeconds)) return 0.0;
    return sim.dx(elapsedSeconds);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    // 越界:交给父链的 spring 回弹——包 clamping 就是硬停回弹、包 bouncing 就是
    // 弹性回弹，本类只定增量速度，不定义边界。
    if (position.outOfRange) {
      return parent?.createBallisticSimulation(position, velocity) ??
          ClampingScrollPhysics(parent: parent).createBallisticSimulation(position, velocity);
    }
    // 停止速度 = 0（用户裁决 2026-07-20）：官方门是 tolerance.velocity
    // （20/dpr px/s），低于它直接判停——fling 尾段爬行期间任何 goBallistic
    // 重启（内容/视口尺寸变化触发 applyNewDimensions、虚拟滚动估高修正等）
    // 一旦撞上门槛就 goIdle，肉眼即"速度降到阈值突然停住"。样条时长随速度
    // 自然收敛（T ∝ v^0.736：20px/s ≈ 31ms、1px/s ≈ 3ms），零门槛不会造成
    // 永续爬行，任意低速都把曲线走完、速度连续归零；真 0（hold / 收场的
    // goBallistic(0)）仍判 idle。
    if (velocity.abs() < precisionErrorTolerance) return null;
    // 会撞界的方向且已经贴界 → 无 fling 可起。
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) return null;
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) return null;

    return _SplineFlingSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: friction,
      maxDuration: maxFlingDuration,
      tolerance: tolerance,
    );
  }
}

/// Android OverScroller / Chromium MobileScroller 样条 fling 的逐式移植。
///
/// 与 [ClampingScrollSimulation] 的关系:距离/时长公式同源(D 完全相等),
/// 但本类保留 **Android 原时长**(官方 Flutter 缩到 0.8254 倍)与**查表样条
/// 形状**(官方 Flutter 用幂律近似)。样条 = 三次贝塞尔:
/// - 时间曲线控制点 y = (0, P1=0.175, P2=0.35, 1);
/// - 位置曲线控制点 y = (0, START_TENSION=0.5, 1, 1)。
/// 张力比使解析初速 `dP/dT(0)·D/T = (0.5/0.175)·0.35·|v| = |v|` 成立
/// (查表首段用弦斜率,dx(0) ≈ v₀,偏差与原版一致)。
///
/// 查表构建(静态一次):对 100 个等分时间点 α 二分求解贝塞尔参数 u 使
/// `T(u)=α`,记录 `P(u)`;运行时线性插值,和原实现 bit 级同构(原为 float,
/// 此处 double,差异 <1e-5)。
class _SplineFlingSimulation extends Simulation {
  _SplineFlingSimulation({
    required this.position,
    required this.velocity,
    required double friction,
    Duration maxDuration = Duration.zero,
    super.tolerance,
  }) {
    final coeff = friction * _kPhysicalCoeff;
    final l = math.log(_kInflexion * velocity.abs() / coeff);
    final decelMinusOne = _kDecelerationRate - 1.0;
    var duration = math.exp(l / decelMinusOne);
    var distance = coeff * math.exp(_kDecelerationRate / decelMinusOne * l);
    // 时长封顶:按恒等式 D = inflexion·|v₀|·T 反解新距离(见 maxFlingDuration
    // 文档)——等价于对该速度调高 friction,曲线整体变陡而形状不变,初速仍
    // 连续、终点速度仍归零。硬切时间会在尾段留非零速度的顿停,故走这条。
    final capSeconds = maxDuration.inMicroseconds / Duration.microsecondsPerSecond;
    if (capSeconds > 0.0 && duration > capSeconds) {
      duration = capSeconds;
      distance = _kInflexion * velocity.abs() * capSeconds;
    }
    _duration = duration;
    _distance = distance * velocity.sign;
  }

  final double position;
  final double velocity;

  /// GetSplineFlingDuration(秒)。
  late final double _duration;

  /// GetSplineFlingDistance(带符号,px)。
  late final double _distance;

  // ---- 官方常量(mobile_scroller.cc / OverScroller.java) ----

  static const int _kNumSamples = 100; // NB_SAMPLES
  static const double _kInflexion = 0.35; // INFLEXION
  static const double _kStartTension = 0.5; // START_TENSION
  static const double _kEndTension = 1.0; // END_TENSION
  static const double _kP1 = _kStartTension * _kInflexion; // 0.175
  static const double _kP2 = 1.0 - _kEndTension * (1.0 - _kInflexion); // 0.35

  /// ComputeDeceleration(0.84):重力 × 米/英寸 × 160dpi × 调校系数,
  /// logical px 口径与 [ClampingScrollSimulation._physicalCoeff] 同值。
  static const double _kPhysicalCoeff = 9.80665 * 39.37 * 160.0 * 0.84;

  /// DECELERATION_RATE = ln(0.78)/ln(0.9) ≈ 2.3582018。
  static final double _kDecelerationRate = math.log(0.78) / math.log(0.9);

  /// SPLINE_POSITION 查表:index i = 时间 i/100 处的距离系数(0..1)。
  /// SPLINE_TIME 原版仅供 OverScroller 撞边调时长用,el 的边界走 clamping
  /// 硬停 + 父级 spring,不移植。
  static final Float64List _splinePosition = _buildSplinePosition();

  /// 原版静态块的二分法逐式移植:xMin 跨迭代携带(α 单调递增,上一解即
  /// 下一解的下界),收敛判据同 1e-5。
  static Float64List _buildSplinePosition() {
    final table = Float64List(_kNumSamples + 1);
    var xMin = 0.0;
    for (var i = 0; i < _kNumSamples; i++) {
      final alpha = i / _kNumSamples;
      var xMax = 1.0;
      double x;
      double coef;
      while (true) {
        x = xMin + (xMax - xMin) / 2.0;
        coef = 3.0 * x * (1.0 - x);
        final tx = coef * ((1.0 - x) * _kP1 + x * _kP2) + x * x * x;
        if ((tx - alpha).abs() < 1e-5) {
          table[i] = coef * ((1.0 - x) * _kStartTension + x) + x * x * x;
          break;
        }
        if (tx > alpha) {
          xMax = x;
        } else {
          xMin = x;
        }
      }
    }
    table[_kNumSamples] = 1.0;
    return table;
  }

  /// 原版 update() 的系数插值:index 段内线性插值距离系数。
  double _distanceCoef(double t) {
    final index = (_kNumSamples * t).floor();
    if (index >= _kNumSamples) return 1.0;
    final tInf = index / _kNumSamples;
    final dInf = _splinePosition[index];
    final velocityCoef = (_splinePosition[index + 1] - dInf) * _kNumSamples;
    return dInf + (t - tInf) * velocityCoef;
  }

  double _velocityCoef(double t) {
    final index = (_kNumSamples * t).floor();
    if (index >= _kNumSamples) return 0.0;
    return (_splinePosition[index + 1] - _splinePosition[index]) * _kNumSamples;
  }

  @override
  double x(double time) {
    if (_duration <= 0.0) return position + _distance;
    final t = clampDouble(time / _duration, 0.0, 1.0);
    return position + _distanceCoef(t) * _distance;
  }

  @override
  double dx(double time) {
    if (_duration <= 0.0) return 0.0;
    final t = clampDouble(time / _duration, 0.0, 1.0);
    return _velocityCoef(t) * _distance / _duration;
  }

  @override
  bool isDone(double time) => time >= _duration;
}

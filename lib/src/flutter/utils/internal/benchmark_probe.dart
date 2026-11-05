/// 控制首次挂载是否跳过构造期样式解析，供回归测试对比快路径与完整路径。
///
/// 默认开启，将构造期与首次 attach 的重复解析合并；仅供 UI 内部和测试使用。
bool elViewDebugUseMountFastPath = true;

/// 挂载分段墙钟追踪开关：`--dart-define=el.mount.trace=true` 才编译进热路径。
///
/// 默认 false 时所有 `if (elMountTraceEnabled)` 分支被 const 折叠删除，
/// 挂载热路径零成本；探针测试打开后可把「滚动上下文单次挂载 60-90µs vs
/// 全热微基准 4.5µs」的差值拆到 createRenderObject / attach / reresolve /
/// payload / focus 各段（段和 ≪ superMount 时余量归 element 机制 + GC 落点）。
const bool elMountTraceEnabled = bool.fromEnvironment('el.mount.trace');

/// [elMountTraceEnabled] 打开时的挂载分段累计账本（µs）。
abstract final class MountTrace {
  /// ViewElement.super.mount 全程（含 createRenderObject / 子树 inflate /
  /// attachRenderObject→render.attach）。
  static int superMountUs = 0;

  /// ElView.createRenderObject（含 MediaQuery 读取 + ElRenderView 构造）。
  static int createRenderObjectUs = 0;

  /// ElRenderView.attach 全程（含首次 cascade）。
  static int attachUs = 0;

  /// `_reresolve` 全程累计（attach 期首次 cascade 为主）。
  static int reresolveUs = 0;

  /// ViewElement._rebuildChildrenAndPayload。
  static int payloadUs = 0;

  /// ViewElement._syncFocusNode + syncGlobalHandlers。
  static int focusUs = 0;

  /// ViewElement.mount 次数。
  static int mountCount = 0;

  /// ViewElement.unmount 全程。
  static int unmountUs = 0;

  /// ElRenderView.detach 全程。
  static int detachUs = 0;

  /// ElRenderView.dispose 全程。
  static int disposeUs = 0;

  /// 内部 TextView 路由：RenderTextView 构造次数。
  static int textViewCtorCount = 0;

  /// 内部 TextView 路由：RenderTextView 构造 + updatePayload 墙钟。
  static int textViewCtorUs = 0;

  /// 内部 TextView 路由：RenderTextView.attach（含 owner 绑定）墙钟。
  static int textViewAttachUs = 0;

  /// ElRenderView 构造函数 body 墙钟（createRenderObjectUs 的子集；
  /// createRenderObjectUs − ctorBodyUs ≈ MQ 读取 + 对象分配 +
  /// 字段初始化器）。
  static int ctorBodyUs = 0;

  /// ctor body 内变体元数据段（dispatcher 判定 + meta 变体扫描 + 结构位掩码）。
  static int ctorVariantScanUs = 0;

  /// ElView 路径：TextViewElement.super.mount 全程（含 ElRenderTextView
  /// 构造 + attach + 子树 inflate）。
  static int elTextMountUs = 0;

  /// ElView 路径：ElRenderTextView 构造（含 intern + assert 白名单）。
  static int elTextCtorUs = 0;

  /// ElView 路径：ElRenderTextView.attach 全程。
  static int elTextAttachUs = 0;

  /// ElView 路径：挂载计数。
  static int elTextMountCount = 0;

  /// ElView 路径：TextViewElement.unmount 全程。
  static int elTextUnmountUs = 0;

  /// ElView 路径：ElRenderTextView.detach 全程。
  static int elTextDetachUs = 0;

  /// ElView 路径：ElRenderTextView.dispose 全程。
  static int elTextDisposeUs = 0;

  /// layoutPureString：span 构造前置段（style/content/宽度参数解析）。
  static int strLayoutPrepUs = 0;

  /// layoutPureString：painter setter + layout（引擎 shaping 主体）。
  static int strLayoutShapeUs = 0;

  /// layoutPureString：调用计数。
  static int strLayoutCount = 0;

  /// 表格稀疏列窗口对齐次数。
  static int tableSparseReconcileCount = 0;

  /// 表格稀疏列窗口增删 render/element 的累计墙钟（µs）。
  static int tableSparseReconcileUs = 0;

  /// 表格稀疏行已挂载 cell 布局的累计墙钟（µs）。
  static int tableSparseChildLayoutUs = 0;

  /// 重置全部累计。
  static void reset() {
    superMountUs = 0;
    createRenderObjectUs = 0;
    attachUs = 0;
    reresolveUs = 0;
    payloadUs = 0;
    focusUs = 0;
    mountCount = 0;
    unmountUs = 0;
    detachUs = 0;
    disposeUs = 0;
    textViewCtorCount = 0;
    textViewCtorUs = 0;
    textViewAttachUs = 0;
    ctorBodyUs = 0;
    ctorVariantScanUs = 0;
    elTextMountUs = 0;
    elTextCtorUs = 0;
    elTextAttachUs = 0;
    elTextMountCount = 0;
    elTextUnmountUs = 0;
    elTextDetachUs = 0;
    elTextDisposeUs = 0;
    strLayoutPrepUs = 0;
    strLayoutShapeUs = 0;
    strLayoutCount = 0;
    tableSparseReconcileCount = 0;
    tableSparseReconcileUs = 0;
    tableSparseChildLayoutUs = 0;
  }

  /// 快照。
  static Map<String, int> snapshot() {
    return <String, int>{
      'mountCount': mountCount,
      'superMountUs': superMountUs,
      'createRenderObjectUs': createRenderObjectUs,
      'attachUs': attachUs,
      'reresolveUs': reresolveUs,
      'payloadUs': payloadUs,
      'focusUs': focusUs,
      'unmountUs': unmountUs,
      'detachUs': detachUs,
      'disposeUs': disposeUs,
      'textViewCtorCount': textViewCtorCount,
      'textViewCtorUs': textViewCtorUs,
      'textViewAttachUs': textViewAttachUs,
      'ctorBodyUs': ctorBodyUs,
      'ctorVariantScanUs': ctorVariantScanUs,
      'elTextMountCount': elTextMountCount,
      'elTextMountUs': elTextMountUs,
      'elTextCtorUs': elTextCtorUs,
      'elTextAttachUs': elTextAttachUs,
      'elTextUnmountUs': elTextUnmountUs,
      'elTextDetachUs': elTextDetachUs,
      'elTextDisposeUs': elTextDisposeUs,
      'strLayoutCount': strLayoutCount,
      'strLayoutPrepUs': strLayoutPrepUs,
      'strLayoutShapeUs': strLayoutShapeUs,
      'tableSparseReconcileCount': tableSparseReconcileCount,
      'tableSparseReconcileUs': tableSparseReconcileUs,
      'tableSparseChildLayoutUs': tableSparseChildLayoutUs,
    };
  }
}

/// benchmark 观测探针。
///
/// 用于 benchmark 场景下统计核心热路径的调用次数（cascade tick / fast patch
/// hit 与 miss / builder.build / performLayout / inheritance propagate）。
/// **所有 increment 只在 assert 内跑**，Release 构建下常量表达式全部被裁掉，
/// 零成本。
///
/// 用法（typical）：
///
/// ```dart
/// BenchmarkProbe.reset();
/// await tester.pumpWidget(...);
/// final snapshot = BenchmarkProbe.snapshot();
/// ```
///
/// 不从公共入口导出；测试通过 `src/flutter/utils/internal/benchmark_probe.dart` 直接导入。
class BenchmarkProbe {
  BenchmarkProbe._();

  /// [CascadeTick.tick] 入口计数。
  static int cascadeTickCount = 0;

  /// **T9a-spike**：[CascadeTick.tick] 主 diff 循环真实迭代的字段数累计。
  ///
  /// 旧 `for (final f in ElTransitionField.values)` 路径每 tick 恒定 54 次
  /// 迭代；新 mask 路径按组切片，仅迭代"组不 identical"组的字段位。命中缓存
  /// / 组 identical 时可直接 0 迭代。
  ///
  /// baseline-2026-07-03.md 未测本字段，对比值 ≈ `cascadeTickCount × 54`。
  static int cascadeFieldIterCount = 0;

  /// [CascadeFastPatch.tryPatch] 命中（返回非 null）计数。
  static int fastPatchHitCount = 0;

  /// [CascadeFastPatch.tryPatch] 未命中（进入 diff 后 bail、或 dirty 空 bail）
  /// 计数。identical / null 早退（bail 0 之前）不计入。
  static int fastPatchMissCount = 0;

  /// **T22** — [CascadeFastPatch.tryInheritPatch] 借用恢复（Servo Arc 式组共享）
  /// 命中计数。
  ///
  /// 命中意味着子节点此前整组借用父的 inheritedText / inheritedBox，父组换新后
  /// 直接借用父的新组对象（零 builder / buffer 分配、零字段拷贝，且 identical
  /// 共享不变量沿子树保持）。深链 color 传播 / ThemeSwap 场景该计数应线性递增，
  /// builderBuildCount 应显著低于旧路径。
  static int inheritBorrowHitCount = 0;

  /// [ResolvedStyleBuilder.build] 入口计数。
  static int builderBuildCount = 0;

  /// [ElRenderView.performLayout] 入口计数。
  static int performLayoutCount = 0;

  /// [InheritancePropagator.propagate] 入口计数。
  static int propagateCount = 0;

  /// **T24** — attach 期 `_reresolve` 触发次数（`_parentResolved` 变化分支）。
  ///
  /// 探针用于实证"attach 期双重 cascade"假设：ContainerRenderObjectMixin 在
  /// super.attach 内先递归 attach 全部子，子 attach 时反查父 committed 走一次
  /// cascade；父 attach 完自身 `_reresolve` 后 damage route → propagate 又让子
  /// 走 reresolveFromInheritance/fast_patch 一次。首挂载 N 节点场景该计数应
  /// 逼近 N（每个子 attach 触发一次），mount fast-path 命中时该值 → 0。
  static int attachReresolveCount = 0;

  /// **T24** — attach 期 `_reresolve` 走 mount fast-path（跳过 diff + damage
  /// route）的命中次数。快路径省 oldCommitted 全字段 diff、跳过 transition 状
  /// 态机、跳过 damage route（子未 attach 无从 propagate，且新 attach 节点整
  /// 体 needsLayout/needsPaint）。
  static int mountFastPathHitCount = 0;

  /// 状态订阅对象的实际分配次数。
  static int stateSourceInstantiateCount = 0;

  /// 样式动画驱动器的实际分配次数。
  static int animDriverInstantiateCount = 0;

  /// 文本排版协作体的实际分配次数。
  static int textLayerInstantiateCount = 0;

  /// 手工固有尺寸缓存的分配次数；现由 RenderBox 管理，保留旧基准字段且恒为零。
  static int intrinsicsCacheInstantiateCount = 0;

  /// 每节点 `PaintController` 实例化累计。
  ///
  /// 零绘制 op 的节点走 `_zeroPaintOpsFor` identity 直通，不 alloc；
  /// 无盒装饰的裸行稳态该值应恒为 0。
  static int paintControllerInstantiateCount = 0;

  /// 旧焦点状态对象的分配占位计数；当前状态由 ViewElement 持有，恒为零。
  static int focusStateInstantiateCount = 0;

  /// 焦点环全局高亮模式监听的登记次数。
  static int focusHighlightListenerAddCount = 0;

  /// 焦点环全局高亮模式监听的注销次数。
  static int focusHighlightListenerRemoveCount = 0;

  /// 亮环或迁桶时查询 Flutter View 的次数。
  static int focusViewIdResolveCount = 0;

  /// 选中换色 overlay 的 `TextPainter.layout` 次数（= 真 shape 次数）。
  ///
  /// 非全选分支要逐 rect clip 重绘，但 overlay 与 rect 无关 —— 一帧应恒 ≤1。
  /// 曾经在 rect 循环里逐次新建 + layout，10 行选区 = 每帧 10 次完整 shape。
  static int selectionOverlayLayoutCount = 0;

  /// 富文本**结构** parse 次数（`TextContent.parse`，phase 1）。
  ///
  /// 只应在 payload 内容变化时发生。hover / tap / dark 翻转、样式变化、重绘
  /// 一律不得触发 —— 那些只重跑样式阶段（见 richTextContextBuildCount）。
  static int textContentParseCount = 0;

  /// 富文本 inline 命中测试次数（`RichInlineHitTester.hitAt` 调用）。
  ///
  /// 每个指针事件应恰 ≤1；曾经一个 hover 事件做 3 次（hover span / hover owner
  /// / 事件派发各一次），每次含 getClosestGlyphForOffset + getBoxesForSelection。
  static int inlineHitTestCount = 0;

  /// `ViewElement._forgottenChildren` 集合分配累计。
  ///
  /// 仅富文本多子路径需要；单 child / 纯文本 / 裸行稳态该值应恒为 0。
  static int forgottenChildrenAllocCount = 0;

  /// rich-inline IFC 构建次数。
  ///
  /// 稳态富文本节点在 rawChild / 结构 / 排版字段不变时应为 0。paint-only 文本
  /// 字段变化会清 IFC；下一次消费若需要新 span，会通过本计数反映重建成本。
  static int richTextContextBuildCount = 0;

  /// 纯字符串快路径 `layoutPureString` 的 painter.layout（shaping）次数。
  ///
  /// 挂载帧每文本节点应恰为 1；>1 说明同帧重复 shaping（约束抖动 / 失效风暴）。
  static int stringPainterLayoutCount = 0;

  /// 重置全部计数字段。
  static void reset() {
    stringPainterLayoutCount = 0;
    cascadeTickCount = 0;
    cascadeFieldIterCount = 0;
    fastPatchHitCount = 0;
    fastPatchMissCount = 0;
    inheritBorrowHitCount = 0;
    builderBuildCount = 0;
    performLayoutCount = 0;
    propagateCount = 0;
    attachReresolveCount = 0;
    mountFastPathHitCount = 0;
    stateSourceInstantiateCount = 0;
    animDriverInstantiateCount = 0;
    textLayerInstantiateCount = 0;
    intrinsicsCacheInstantiateCount = 0;
    paintControllerInstantiateCount = 0;
    focusStateInstantiateCount = 0;
    focusHighlightListenerAddCount = 0;
    focusHighlightListenerRemoveCount = 0;
    focusViewIdResolveCount = 0;
    selectionOverlayLayoutCount = 0;
    textContentParseCount = 0;
    inlineHitTestCount = 0;
    forgottenChildrenAllocCount = 0;
    richTextContextBuildCount = 0;
  }

  /// 返回当前所有计数字段的快照。
  static Map<String, int> snapshot() {
    return <String, int>{
      'cascadeTickCount': cascadeTickCount,
      'cascadeFieldIterCount': cascadeFieldIterCount,
      'fastPatchHitCount': fastPatchHitCount,
      'fastPatchMissCount': fastPatchMissCount,
      'inheritBorrowHitCount': inheritBorrowHitCount,
      'builderBuildCount': builderBuildCount,
      'performLayoutCount': performLayoutCount,
      'propagateCount': propagateCount,
      'attachReresolveCount': attachReresolveCount,
      'mountFastPathHitCount': mountFastPathHitCount,
      'stateSourceInstantiateCount': stateSourceInstantiateCount,
      'animDriverInstantiateCount': animDriverInstantiateCount,
      'textLayerInstantiateCount': textLayerInstantiateCount,
      'intrinsicsCacheInstantiateCount': intrinsicsCacheInstantiateCount,
      'paintControllerInstantiateCount': paintControllerInstantiateCount,
      'focusStateInstantiateCount': focusStateInstantiateCount,
      'focusHighlightListenerAddCount': focusHighlightListenerAddCount,
      'focusHighlightListenerRemoveCount': focusHighlightListenerRemoveCount,
      'focusViewIdResolveCount': focusViewIdResolveCount,
      'selectionOverlayLayoutCount': selectionOverlayLayoutCount,
      'textContentParseCount': textContentParseCount,
      'inlineHitTestCount': inlineHitTestCount,
      'forgottenChildrenAllocCount': forgottenChildrenAllocCount,
      'richTextContextBuildCount': richTextContextBuildCount,
      'stringPainterLayoutCount': stringPainterLayoutCount,
    };
  }
}

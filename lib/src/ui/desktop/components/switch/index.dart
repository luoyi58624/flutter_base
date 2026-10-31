import 'package:flutter_base/src/ui/desktop/internal.dart';
import 'package:flutter/widgets.dart';

// 品牌尺寸档位表（xs/sm/md/lg/xl），显式参数优先于档位默认值。
// 三参数模型：heights = switch 最终高度（轨道高/行高），gaps = 滑块与轨道
// 边缘间距，滑块直径 = heights - 2*gaps，widthAspects = 轨道宽高比。
// 档位值沿用现有高度与间距，lg = 移动端默认。
List<double> get _heights => const [20.0, 24.0, 26.0, 30.0, 32.0];

List<double> get _gaps => const [2.0, 2.0, 2.0, 3.0, 3.0];

/// 轨道宽高比档（xs/sm/md/lg/xl）。
List<double> get _widthAspects => const [1.75, 1.75, 1.75, 1.75, 1.75];

/// Element 开关主题实现：只服务 [ElementPlusThemeData]，由 barrel 挡住、不经 `element_plus.dart` 导出。
class Switch extends ElFormModelValue<bool> {
  Switch(this.component, {super.key})
    : super(
        value: component.value,
        modelValue: component.modelValue,
        onChanged: component.onChanged,
      );

  final ElSwitch component;

  @override
  Widget obsBuilder(BuildContext context) {
    final on = $obs.value;
    final resolved = context.elComponentSize(component.style);
    return _SwitchBody(
      config: component,
      on: on,
      toggle: () => $obs.value = !$obs.value,
      resolved: resolved,
      slide: component.slide,
    );
  }
}

extension _SwitchAppearance on ElSwitch {
  bool get _interactive => !disabled && !loading;
  // 官方 switch 使用 transition: all .3s，未指定 timing-function 时为 CSS ease。
  Duration get _duration =>
      slide ? const Duration(milliseconds: 300) : Duration.zero;

  // 注意：这里不能带 alignment —— el_ui 引擎里 alignment 非空 = 块级撑满
  // 父宽（见 el_render_view._layoutWidgetOrEmpty），开关会独占一行。
  // 垂直居中天然成立：行高 = height，唯一子 ElView 的高度恒等于行高。
  //
  // 外壳向下传文本样式：轨道内内容直接吃白色 + 12px（官方 `__inner` 口径），
  // 滑块内内容在 [_thumb] 里覆盖成轨道色。icon 样式同源注入——
  // iconSize 12 与 iconColor（currentColor = 外壳文字色）都在这一层声明，
  // 内层 [elContent] 不再显式传尺寸/颜色，全部吃继承。
  ElStyle _rootStyle(BuildContext context, ElLevelType resolved) => ElStyle(
    height: _heightOf(context, resolved),
    fontSize: 12,
    color: context.elTheme.white,
    iconSize: 12,

    cursor: _interactive
        ? SystemMouseCursors.click
        : SystemMouseCursors.forbidden,
    userSelect: .none,
    // 官方禁用把整体压到 0.6 透明度
    onDisabled: const ElStyle(
      opacity: 0.6,
      cursor: SystemMouseCursors.forbidden,
    ),
    iconColor: context.elTheme.white,
  );

  Color _trackColor(BuildContext context, bool on) {
    final custom = on ? activeColor : inactiveColor;
    if (custom is Color) return custom;
    return (on
        ? context.elTheme.primary
        : context.elTheme.borderColor);
  }

  /// 轨道本体（几何 + 轨道色 + 滑块定位）。
  Widget _core(
    BuildContext context,
    ElLevelType resolved,
    bool on, {
    bool slide = true,
    double contentWidth = 0,
    GlobalKey? activeWKey,
    GlobalKey? inactiveWKey,
  }) {
    // 有内容即内嵌（官方 inline-prompt）：轨道宽度随内容生长，官方宽度只当
    // 下限；无内容时锁死官方宽度、滑块直接贴边滑动。
    final hasContent = activeContent != null || inactiveContent != null;
    return ElView(
      style: ElStyle(
        width: hasContent ? null : _containerWidth(context, resolved),
        minWidth: hasContent ? _containerWidth(context, resolved) : null,
        height: _heightOf(context, resolved),
        backgroundColor: _trackColor(context, on),
        border: ElBorder.all(borderWidth: 1, borderColor: _trackColor(context, on)),
        borderRadius: BorderRadius.circular(_heightOf(context, resolved) / 2),
        padding: EdgeInsets.all(_gapOf(resolved)),
        alignment: hasContent
            ? null
            : (on ? Alignment.centerRight : Alignment.centerLeft),
        clipBehavior: hasContent ? Clip.antiAlias : null,
        onFocusVisible: ElStyle(
          outline: ElOutline(
            outlineWidth: 2,
            outlineColor: _trackColor(context, true),
            outlineOffset: 1,
          ),
        ),
        transition: !slide
            ? const [ElTransition.all(Duration.zero)]
            : [ElTransition.all(_duration, Curves.ease)],
      ).merge(trackStyle),
      child: hasContent
          ? _inlineContent(
              context,
              resolved,
              on,
              contentWidth: contentWidth,
              activeWKey: activeWKey,
              inactiveWKey: inactiveWKey,
            )
          : _thumb(context, resolved, on),
    );
  }

  /// 轨道内内容档（官方 inline-prompt）。
  ///
  /// 内容层按**内在尺寸**排（用户 Widget + 让开滑块的内边距），轨道宽度就是
  /// 它撑出来的；滑块层走 `ElPositioned.fill` 盖上去，只按 alignment 滑动、
  /// 不参与定宽。
  ///
  /// 官方是「`__inner` 占满 100% + `justify-content: center` + 非对称 padding」，
  /// 本实现是「内在宽度层被 ElStackView 居中」——两者内容中心线都落在
  /// `(W + padLeft - padRight) / 2`，等价。
  Widget _inlineContent(
    BuildContext context,
    ElLevelType resolved,
    bool on, {
    double contentWidth = 0,
    GlobalKey? activeWKey,
    GlobalKey? inactiveWKey,
  }) {
    final thumbSize = _thumbSize(context, resolved);
    final gap = _gapOf(resolved);
    // 滑块进度（0 = 贴左 / 1 = 贴右），与滑块 alignment 补间同源
    final t = on ? 1.0 : 0.0;
    // 内容层盒宽 = 内容宽 + 两侧让位（与 width 公式同构，动画同步）
    final layerWidth = contentWidth + thumbSize + gap + 12;
    // 让位 padding（与内容层 padding 同源，动画同步）
    final padLeft = on ? gap + 6 : thumbSize + 6;
    // 滑块左缘/右缘（相对内容区左缘）：显示裁剪边界——滑块是内容的边界，
    // active 只显示滑块左缘左侧、inactive 只显示滑块右缘右侧
    final thumbLeft = t * (layerWidth - thumbSize) - padLeft;
    final thumbRight = thumbLeft + thumbSize;
    // 切换 300ms，与滑块补间同曲线同步
    final positionDuration = _duration;
    return ElStackView(
      alignment: .center,
      children: [
        ElView(
          style: ElStyle(
            // 官方 `__inner` 高度 = 滑块直径，三档都正好等于轨道内容区高度
            height: thumbSize,
            // 官方 `__inner { justify-content: center; align-items: center }`。
            // 竖直方向必须有：行盒只有 12px，比这里的 16px 矮，不居中就贴顶。
            // 这里不怕 alignment 撑满 —— Row 给非 flex 子的主轴约束是无界的，
            // `_layoutWidgetOrEmpty` 那条 `maxWidth.isFinite` 分支走不到；
            // 只有调用方显式传了 [width] 才有界，那时撑满正是官方 `width: 100%`
            alignment: .center,
            // 开关文案按紧凑单行排版，避免默认 font metrics 的额外 leading
            // 把字形墨迹视觉上压向下方。
            lineHeight: 1,
            // 两侧各保留 6px 内容留白，并让开圆块占据的区域。
            padding: EdgeInsets.only(
              left: on ? gap + 6 : thumbSize + 6,
              right: on ? thumbSize + 6 : gap + 6,
            ),
            // 切换时内容层宽/让位走 300ms 过渡，与滑块滑动同步
            transition: [ElTransition.all(_duration, Curves.ease)],
            // 盒宽 = 内容宽 + 两侧让位 padding（el_ui 的 width 是整盒宽，
            // padding 在盒内）：切换时 width 与 padding 同步动画——
            // 与滑块滑动同引擎同曲线，滑块按 alignment 比例定位天然精准同步
            width: contentWidth + thumbSize + gap + 12,
          ),
          // 内容区必须无条件渲染：ElStackView 无非定位子会撑满父宽。无内容时
          // 空层在 Row 无界主轴下 contentSize = 0（只留 padding），
          // 宽度被 core 的 minWidth 兜底 → 轨道宽度 = 官方宽度。
          //
          // **无界内容 + 裁剪**：内容在 OverflowBox 内按内在宽布局
          // （宽度动画中间帧盒子窄于内容时不会触发 RenderFlex / 约束盒
          // 溢出报错），ClipRect 裁掉超出部分；宽度动画由本层 width
          // transitions 承担。显示层 = 当前态内容（AnimatedOpacity 交叉
          // 淡入淡出）；测量层 × 2 透明 ElPositioned（不参与撑宽），
          // 布局后回填实测宽供宽度计算。
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: double.infinity,
              child: ElStackView(
                // 左对齐：显示层与滑块同坐标系（内容区左缘为基准），
                // 居中会因对侧较宽层把文本推向偏移
                alignment: Alignment.centerLeft,
                children: [
                  // 测量层 × 2（透明，定位到左上角取自身宽）
                  ElPositioned(
                    left: 0,
                    top: 0,
                    child: ElView(
                      key: activeWKey,
                      style: const ElStyle(opacity: 0),
                      child: elContent(activeContent),
                    ),
                  ),
                  ElPositioned(
                    left: 0,
                    top: 0,
                    child: ElView(
                      key: inactiveWKey,
                      style: const ElStyle(opacity: 0),
                      child: elContent(inactiveContent),
                    ),
                  ),
                  // 显示层 × 2：盒子位置 = 让位动画（内容层 padding 驱动，
                  // 切换时文本朝滑块方向移动）；显示经 _RegionClipper 按滑块
                  // 边界裁剪——active 只显示滑块左缘左侧、inactive 只显示
                  // 滑块右缘右侧，文本**永不显示在滑块另一边**、两文本显示
                  // 区分居滑块两侧互不重叠；裁剪边界经 TweenAnimationBuilder
                  // 与滑块补间同曲线同步。AnimatedOpacity 交叉淡入淡出：
                  // 切换 300ms 过渡（与宽度/滑块动画同步）
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: thumbLeft),
                    duration: positionDuration,
                    curve: Curves.ease,
                    builder: (_, clip, child) => ClipRect(
                      clipper: _RegionClipper(right: clip),
                      child: child,
                    ),
                    child: ElView(
                      style: const ElStyle(alignment: .center),
                      child: AnimatedOpacity(
                        opacity: on ? 1.0 : 0.0,
                        duration: positionDuration,
                        curve: Curves.ease,
                        child: ElView(child: elContent(activeContent)),
                      ),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: thumbRight),
                    duration: positionDuration,
                    curve: Curves.ease,
                    builder: (_, clip, child) => ClipRect(
                      clipper: _RegionClipper(left: clip),
                      child: child,
                    ),
                    child: ElView(
                      style: const ElStyle(alignment: .center),
                      child: AnimatedOpacity(
                        opacity: on ? 0.0 : 1.0,
                        duration: positionDuration,
                        curve: Curves.ease,
                        child: ElView(child: elContent(inactiveContent)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ElPositioned.fill(
          child: ElView(
            style: ElStyle(
              // 关贴左、开贴右，两端补间滑动
              alignment: on ? .centerRight : .centerLeft,
              transition: [ElTransition.all(_duration, Curves.ease)],
            ),
            child: _thumb(context, resolved, on),
          ),
        ),
      ],
    );
  }

  /// 切换时保持圆块尺寸不变，仅让轨道负责位移。
  Widget _thumb(BuildContext context, ElLevelType resolved, bool on) {
    final thumbSize = _thumbSize(context, resolved);
    return ElView(
      style: ElStyle(
        width: thumbSize,
        height: thumbSize,
        backgroundColor: context.elTheme.white,
        borderRadius: .all(Radius.circular(thumbSize / 2)),
        alignment: .center,
        color: _trackColor(context, on),
        transition: [ElTransition.all(_duration, Curves.ease)],
        iconColor: _trackColor(context, on),
      ),
      child: loading
          ? ElLoading(child: ElIcon(ElIcons.loading, size: thumbSize * 0.7))
          : AnimatedSwitcher(
              duration: _duration,
              switchInCurve: Curves.ease,
              switchOutCurve: Curves.ease,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _actionChild(
                on ? activeActionContent : inactiveActionContent,
              ),
            ),
    );
  }

  /// 滑块内 action 内容归一化（带替换 key）：Widget/IconData 直通（不额外包
  /// ElView，保持样式继承链与载荷解析），其余（String 等文本载荷）包 ElView 承载。
  Widget _actionChild(Object? content) {
    final resolved = elContent(content);
    return KeyedSubtree(
      key: ValueKey<Object?>(content),
      child: resolved is Widget ? resolved : ElView(child: resolved),
    );
  }

  /// 显式高度和间距优先于品牌尺寸档。
  double _heightOf(BuildContext context, ElLevelType size) =>
      height ?? _heights[size.index];

  double _gapOf(ElLevelType size) => gap ?? _gaps[size.index];

  double _containerWidth(BuildContext context, ElLevelType size) =>
      _heightOf(context, size) * (widthAspect ?? _widthAspects[size.index]);

  double _thumbSize(BuildContext context, ElLevelType size) =>
      (_heightOf(context, size) - 2 * _gapOf(size)).clamp(0.0, double.infinity);
}

/// 渲染主体（独立 StatefulWidget）：tap 切换由引擎手势裁决，切换后滑块补间
/// 滑动；不做拖拽（拖拽滑块与滚动容器竞争手势，砍掉省心，官方 Web 也不拖拽）。
class _SwitchBody extends StatefulWidget {
  const _SwitchBody({
    required this.config,
    required this.on,
    required this.toggle,
    required this.resolved,
    required this.slide,
  });

  final ElSwitch config;
  final bool on;
  final VoidCallback toggle;
  final ElLevelType resolved;

  /// 滑动动画开关（slide 参数）
  final bool slide;

  @override
  State<_SwitchBody> createState() => _SwitchBodyState();
}

class _SwitchBodyState extends State<_SwitchBody> {
  /// 开/关两态内容的实测宽度（测量层布局后经 postFrame 回填）。
  /// 轨道宽 = 当前显示内容宽（切换动画过渡）。
  double? _activeContentW;
  double? _inactiveContentW;
  final GlobalKey _activeWKey = GlobalKey();
  final GlobalKey _inactiveWKey = GlobalKey();

  /// 内容宽测量是否已回填：内容档首帧测量未就绪时 Offstage 隐藏，
  /// 避免用户看到「官方宽 → 实测宽」的挂载宽度跳变，第二帧直接以正确
  /// 宽度渲染（无内容档宽度天然正确，不走 Offstage）
  bool _measured = false;

  /// 内容区宽度（不含外层让位 padding）：切换时由内容层 ElView 的
  /// width transitions 动画过渡
  double _contentWidth(double? measuredActive, double? measuredInactive) =>
      widget.on ? (measuredActive ?? 0.0) : (measuredInactive ?? 0.0);

  /// 布局后回填两态内容实测宽（首帧回填后解除 Offstage，只在变化时 setState）
  void _measureContentWidths() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = _activeWKey.currentContext?.size?.width;
      final i = _inactiveWKey.currentContext?.size?.width;
      if (a == null || i == null) return;
      if (a != _activeContentW || i != _inactiveContentW || !_measured) {
        setState(() {
          _activeContentW = a;
          _inactiveContentW = i;
          _measured = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final on = widget.on;
    final resolved = widget.resolved;
    void toggle() => widget.toggle();
    _measureContentWidths();

    final userEvent = config.event ?? ElEvent();

    final body = ElView(
      // loading / 禁用期间摘掉节点，与旧 focus 配置的可聚焦口径一致
      focusNode: config._interactive ? config.focusNode : null,
      event: config.disabled
          ? ((config._interactive
                        ? ElButtonView.buildEvent(toggle, false, userEvent)
                        : null) ??
                    ElEvent())
                .copyWith(disabled: true)
          : (config._interactive
                ? ElButtonView.buildEvent(toggle, false, userEvent)
                : null),
      semantics: ElSemantics(
        mergeDescendants: true,
        toggled: on,
        enabled: !config.disabled,
        label: config.semanticLabel,
        onTap: config._interactive ? toggle : null,
      ),
      style: config._rootStyle(context, resolved).merge(config.style),
      // Row 主轴无界：inline 档空内容层在无界约束下 contentSize = 0（只留
      // padding），轨道宽度由 minWidth 兜底；直接放 core 会拿有界父宽，
      // 空内容层撑满、轨道占满整行（见 el_render_view._layoutWidgetOrEmpty
      // 空盒「有界取 maxW、无界取 0」的口径）。
      child: Row(
        mainAxisSize: .min,
        crossAxisAlignment: .center,
        children: [
          config._core(
            context,
            resolved,
            on,
            slide: widget.slide,
            contentWidth: _contentWidth(_activeContentW, _inactiveContentW),
            activeWKey: _activeWKey,
            inactiveWKey: _inactiveWKey,
          ),
        ],
      ),
    );
    // 内容档首帧（测量未回填）Offstage 隐藏：内容宽要布局后测量回填，
    // 直接渲染会露出「官方宽 → 实测宽」的挂载宽度跳变；第二帧测量就绪
    // 直接以正确宽度渲染。无内容档宽度天然正确，不走 Offstage。
    final hasContent =
        config.activeContent != null || config.inactiveContent != null;
    return hasContent && !_measured
        ? Offstage(offstage: true, child: body)
        : body;
  }
}

/// 矩形区域裁剪：`left` 裁掉盒子左侧、`right` 裁掉盒子右侧（相对盒子原点）。
///
/// 开关内嵌内容档用它把显示层按滑块边界裁开——active 只显示滑块左缘左侧、
/// inactive 只显示滑块右缘右侧，文本永远不显示在滑块另一边（盒子位置仍走
/// 原版让位动画，只裁显示，不挪位置）。
class _RegionClipper extends CustomClipper<Rect> {
  const _RegionClipper({this.left, this.right});

  /// 左裁边界（null = 不裁左侧）
  final double? left;

  /// 右裁边界（null = 不裁右侧）
  final double? right;

  @override
  Rect getClip(Size size) {
    final l = (left ?? 0.0).clamp(0.0, size.width).toDouble();
    final r = (right ?? size.width).clamp(0.0, size.width).toDouble();
    return Rect.fromLTRB(l, 0, r, size.height);
  }

  @override
  bool shouldReclip(_RegionClipper oldClipper) =>
      left != oldClipper.left || right != oldClipper.right;
}

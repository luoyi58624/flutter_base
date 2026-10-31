part of 'render_view.dart';

/// 按样式编排盒装饰绘制，并管理图片订阅和合成图层的生命周期。
class PaintController {
  /// 创建。
  PaintController(this._host) {
    assert(() {
      BenchmarkProbe.paintControllerInstantiateCount++;
      return true;
    }());
  }

  final ElRenderView _host;

  /// 共享 solid 色画笔：唯一写字段 color 且每次使用前必写；canvas.draw* 调用
  /// 瞬间即完成序列化，不持画笔引用，跨节点共享安全。
  static final Paint _solidColorPaint = Paint();

  /// backdropFilter layer 句柄（filter 非 null 时挂载，filter == null 时清空）。
  ///
  /// 五个 layer 句柄全部懒建：backdrop / filter 通道是极小概率路径，不让每个
  /// 节点的首次 paint 预付 5 个 LayerHandle 分配；空句柄与 `layer == null` 等价。
  LayerHandle<BackdropFilterLayer>? _backdropLayerHandle;

  /// 自身 filter layer 句柄（box.filter 解析非恒等时挂载）。
  LayerHandle<ImageFilterLayer>? _filterLayerHandle;

  /// 背景滤镜只持有当前使用的裁剪层，切换形状时自动释放旧层。
  LayerHandle<ContainerLayer>? _backdropClipLayerHandle;

  /// 持久化 backgroundImage painter（跨 frame）+ 当前持有的 image 引用（identity 比对）。
  ///
  /// `DecorationImagePainter` 内部持有 `ImageStream.addListener`，dispose 后
  /// 异步图片加载完成 → 监听不触发 → 图片永远不显示。所以这里在 paint 阶段
  /// **保留** painter，仅在 image 引用变化时 dispose 旧的 + create 新的。
  DecorationImagePainter? _bgImagePainter;
  DecorationImage? _bgImagePainterFor;

  /// 测试观察：当前 backgroundImage painter 持有的 image 引用（identity 用于不变量验证）。
  DecorationImage? get bgImagePainterFor => _bgImagePainterFor;

  /// 测试观察：当前 backgroundImage painter 实例（identity 用于跨 frame 复用验证）。
  Object? get bgImagePainter => _bgImagePainter;

  /// dispose 资源（host.dispose 内调）。
  void dispose() {
    _backdropLayerHandle?.layer = null;
    _filterLayerHandle?.layer = null;
    _backdropClipLayerHandle?.layer = null;
    _ensureBgImagePainter(null);
    _paintOpBitsFor = null;
  }

  // --- paint op 位（分类器） -------------------------------------------------
  //
  // 浏览器式结构：op 存在性在「样式真变」时一次判定（ComputedStyle 派生
  // 标志位的类比），paint 每帧只读位。前一版的三形态枚举
  // （empty / bgOnly / bgRadiusOnly）扩展为逐 op 位——任意属性组合的成本
  // = 各自 op 的一条 canvas 指令，加属性不再跌落"全量慢路径"悬崖。
  //
  // 同一 box 的绘制字段存在性不变，复用分类结果。
  static const int _opBg = 1 << 0;

  /// 几何修饰位（不是独立 op）：radius 单独存在无 bg / clip 时本就无绘制
  /// 输出（W2 裁决），分类归零走 children 直通。
  static const int _opRadius = 1 << 1;
  static const int _opBorder = 1 << 2;
  static const int _opShadow = 1 << 3;
  static const int _opBgImage = 1 << 4;
  static const int _opGradient = 1 << 5;
  static const int _opOutline = 1 << 6;

  /// clipBehavior 裁 children（步 5-7）。
  static const int _opClip = 1 << 7;

  /// 自定义 clipper path 裁整段盒装饰（CSS clip-path 语义）。
  static const int _opClipper = 1 << 8;
  static const int _opTransform = 1 << 9;
  static const int _opOpacity = 1 << 10;
  static const int _opBackdrop = 1 << 11;

  /// 自身滤镜（CSS filter：ImageFilterLayer 包整段 stacking context）。
  static const int _opFilter = 1 << 12;

  /// 需要包裹层（layer / saveLayer / clipPath 包整段 stacking context）的位。
  static const int _opWrapMask = _opClipper | _opTransform | _opOpacity | _opBackdrop | _opFilter;

  int _paintOpBits = 0;

  Box? _paintOpBitsFor;

  /// 测试观察：op 位分类真正重扫字段的次数（identity 缓存命中不计入）。
  /// 仅 debug（assert 开）模式下有效。
  int paintShapeClassifyCountForTest = 0;

  /// 测试观察：本节点构建复杂绘制几何的次数，仅 debug 有效。
  int paintPlanBuildCountForTest = 0;

  /// 最终解析 box → 绘制 op 位。纯结构函数，宿主的零 op 直通路径也用它
  /// 判定「该不该为 paint 编排分配控制器」。
  static int classifyPaintOps(Box box) {
    var bits = 0;
    // bg：paint 期已是字面色（var 未定义解析为 null → 无 op，与旧
    // `bg is Color` 门一致）。
    if (box.backgroundColor != null) bits |= _opBg;
    if (box.borderRadius != null) bits |= _opRadius;
    if (box.border != null) bits |= _opBorder;
    final shadows = box.boxShadow;
    if (shadows?.isNotEmpty ?? false) bits |= _opShadow;
    if (box.backgroundImage != null) bits |= _opBgImage;
    if (box.gradient != null) bits |= _opGradient;
    if (box.outline != null) bits |= _opOutline;
    final clip = box.clipBehavior;
    if (clip != null && clip != Clip.none) bits |= _opClip;
    if (box.clipPath != null) bits |= _opClipper;
    if (box.transform != null) bits |= _opTransform;
    if (box.opacity != null && ViewBoxPainter.opacityAlpha(box.opacity) < 255) bits |= _opOpacity;
    if (box.backdropFilter != null && !box.backdropFilter!.isIdentity) bits |= _opBackdrop;
    if (box.filter != null && !box.filter!.isIdentity) bits |= _opFilter;
    if ((bits & ~_opRadius) == 0) return 0;
    return bits;
  }

  // --- paint 主入口 ----------------------------------------------------------

  /// paint 主入口。host 的 `paint(context, offset)` 直接委托过来。
  void paint(PaintingContext context, Offset offset) {
    final resolved = _host.committedResolvedStyle;
    final box = resolved.box;

    // op 位分类缓存：位是最终解析 box 的纯结构函数，box identity 不变 ⇒
    // 位必不变。稳态重绘每帧只付 1 次 identical + 位测试。
    var bits = _paintOpBits;
    if (!identical(box, _paintOpBitsFor)) {
      bits = classifyPaintOps(box);
      _paintOpBitsFor = box;
      _paintOpBits = bits;
      // 跨 frame 资源在位迁移点收尾（backgroundImage / backdropFilter / filter 被
      // 移除的换装帧）——位不含对应 op 而资源仍在 ⇒ 上一形态遗留，必须释放。
      if ((bits & _opBgImage) == 0 && _bgImagePainter != null) _ensureBgImagePainter(null);
      if ((bits & _opBackdrop) == 0 && _backdropLayerHandle?.layer != null) {
        _backdropLayerHandle?.layer = null;
        _backdropClipLayerHandle?.layer = null;
      }
      if ((bits & _opFilter) == 0 && _filterLayerHandle?.layer != null) {
        _filterLayerHandle?.layer = null;
      }
      assert(() {
        paintShapeClassifyCountForTest++;
        return true;
      }());
    }

    // 零绘制 op ⇒ 无事可做，children 直通。这不是形态组合枚举，是唯一的
    // 退化分支；其余一切组合走同一条 plan + 逐位发射管线。
    if (bits == 0) {
      _host.paintContent(context, offset);
      return;
    }

    final boxOffset = offset + _host.boxOrigin;

    final outerRect = boxOffset & _host.boxSize;

    // bg-only（无 radius / 无其他 op）直发快路径：唯一输出是外接矩形一条
    // drawRect，共享几何对该形态全是白付（contentRRect 从
    // 不被发射端消费）。形态迁移安全：位一旦不再恰为 bg 就回到 plan 管线，
    // 并按本次绘制的输入构建几何。
    if (bits == _opBg) {
      context.canvas.drawRect(outerRect, _solidColorPaint..color = box.backgroundColor!);
      _host.paintContent(context, offset);
      return;
    }

    final radius = ViewBoxPainter.effectiveBorderRadius(
      box,
      textDirection: _host.committedResolvedStyle.inheritedBox.direction ?? TextDirection.ltr,
    );
    final geometry = (
      outer: outerRect,
      radius: radius,
      contentRRect: ViewBoxPainter.resolveContentRRect(outerRect, radius),
    );
    assert(() {
      paintPlanBuildCountForTest++;
      return true;
    }());

    // 半透明节点由宿主 OpacityLayer 统一复合时，本层不再重复包 opacity。
    // 同时把 opacity 位从 wrap 判定剔除，让纯 opacity 节点回到直发路径。
    final alpha = _host._usesCompositedOpacity || (bits & _opOpacity) == 0
        ? 255
        : ViewBoxPainter.opacityAlpha(box.opacity);
    final wrapBits = alpha == 255 ? bits & ~_opOpacity : bits;

    // 无包裹层字段：盒装饰逐位直发，零闭包零 layer。
    if ((wrapBits & _opWrapMask) == 0) {
      _emitBoxOps(context, offset, bits, box, geometry);
      return;
    }

    // 包裹层路径：filter（最外）→ backdropFilter → transform / opacity →
    // clipper → 盒装饰。只有声明这些字段的节点才走到这里，包裹成本随声明走。
    // 内层盒装饰与直发路径共用 [_emitBoxOps]。
    void paintAll(PaintingContext ctx, Offset off) {
      if (alpha == 0) return;
      // 子层可能切换 context.canvas，包裹均经 painter 回调，不跨回调缓存 Canvas。
      void emitBox(PaintingContext innerCtx, Offset _) => _emitWithClipper(innerCtx, offset, bits, box, geometry);
      void paintOpacity(PaintingContext innerCtx, Offset _) {
        if (alpha == 255) {
          emitBox(innerCtx, offset);
        } else {
          // 普通半透明由宿主复合；此处分支只会落在滤镜必需的合成路径。
          assert(_host.needsCompositing, '局部透明度只应出现在滤镜合成路径。');
          innerCtx.pushOpacity(Offset.zero, alpha, emitBox);
        }
      }

      final transform = ViewBoxPainter.resolveEffectiveTransform(offset: off, size: _host.boxSize, resolved: resolved);
      // 完整矩阵已含围绕 box 原点的平移；传零偏移避免再次平移，
      // 装饰仍经 emitBox 使用节点原始 offset。
      if (transform == null) {
        paintOpacity(ctx, off);
      } else {
        ctx.pushTransform(_host.needsCompositing, Offset.zero, transform, paintOpacity);
      }
    }

    void paintWithBackdrop(PaintingContext ctx, Offset off) {
      final backdrop = (bits & _opBackdrop) != 0 ? box.backdropFilter!.resolveToImageFilter() : null;
      if (backdrop == null) {
        paintAll(ctx, off);
        return;
      }
      final backdropHandle = _backdropLayerHandle ??= LayerHandle<BackdropFilterLayer>();
      backdropHandle.layer ??= BackdropFilterLayer(filter: backdrop);
      backdropHandle.layer!.filter = backdrop;
      // 背景滤镜的采样必须由合成裁剪层约束，不能只裁 canvas。
      final size = _host.boxSize;
      final bounds = Offset.zero & size;
      final radius = ViewBoxPainter.effectiveBorderRadius(
        box,
        textDirection: _host.committedResolvedStyle.inheritedBox.direction ?? TextDirection.ltr,
      );
      final Object clip = box.clipPath?.getClip(size) ?? radius?.toRRect(bounds) ?? bounds;
      final clipHandle = _backdropClipLayerHandle ??= LayerHandle<ContainerLayer>();
      clipHandle.layer = _pushClip(
        ctx,
        off,
        bounds,
        clip,
        (innerCtx, innerOff) => innerCtx.pushLayer(backdropHandle.layer!, paintAll, innerOff),
        compositing: true,
        behavior: clip is Rect ? Clip.hardEdge : Clip.antiAlias,
        oldLayer: clipHandle.layer,
      );
    }

    final selfFilter = (bits & _opFilter) != 0 ? box.filter!.resolveToImageFilter() : null;
    if (selfFilter != null) {
      // CSS filter 语义：作用于节点全部视觉（含 shadow / outline / children），
      // 模糊溢出边界自然发散，不裁剪。
      final handle = _filterLayerHandle ??= LayerHandle<ImageFilterLayer>();
      handle.layer ??= ImageFilterLayer(imageFilter: selfFilter);
      handle.layer!.imageFilter = selfFilter;
      context.pushLayer(handle.layer!, paintWithBackdrop, boxOffset);
    } else {
      paintWithBackdrop(context, boxOffset);
    }
  }

  /// 自定义 clipper：对齐 Flutter `ClipPath` / CSS `clip-path` —— 包整段盒
  /// 装饰（shadow / bg / border / children / outline 全被裁）。getClip 返回
  /// 局部坐标 path，shift 到外接矩形左上。clipper 语义上可逐帧动态
  /// （shouldReclip 由使用方掌控），每次绘制读取当前 path——声明 clipper 的节点
  /// 自己承担逐帧 getClip 成本。
  void _emitWithClipper(PaintingContext context, Offset childOffset, int bits, Box box, _BoxGeometry geometry) {
    if ((bits & _opClipper) == 0) {
      _emitBoxOps(context, childOffset, bits, box, geometry);
      return;
    }
    final clipPath = box.clipPath!.getClip(geometry.outer.size).shift(geometry.outer.topLeft);
    context.pushClipPath(_host.needsCompositing, Offset.zero, geometry.outer, clipPath, (innerCtx, _) {
      _emitBoxOps(innerCtx, childOffset, bits, box, geometry);
    });
  }

  /// 盒装饰十步发射 —— 严格对齐 CSS Backgrounds & Borders L3 §3.10：
  /// 1. **shadows (outset)** — 沿 outer RRect 偏移 + spread
  /// 2. **bgColor** — CSS 强制最底
  /// 3. **backgroundImage** — DecorationImage，在 content RRect 内
  /// 4. **gradient** — CSS 短手 `background: <grad>, <img>` 默认 grad 在上
  /// 5. **shadows (inset)** — 裁剪到 content RRect 内，覆盖背景
  /// 6–8. **clip + children + restore** — clipBehavior 裁 children 到
  ///    content RRect（needsCompositing 时走 Clip*Layer，否则 canvas clip）
  /// 9. **border** — 沿盒边缘中心线直绘，**不被 #6 clip 裁**
  /// 10. **outline** — border 之外，同不被 #6 裁；customClipper 会裁
  void _emitBoxOps(PaintingContext context, Offset childOffset, int bits, Box box, _BoxGeometry geometry) {
    if ((bits & _opShadow) != 0) {
      ViewBoxPainter.paintShadows(
        context.canvas,
        outerRRect: geometry.contentRRect,
        shadows: box.boxShadow!,
        inset: false,
      );
    }
    if ((bits & _opBg) != 0) {
      if ((bits & _opRadius) != 0) {
        context.canvas.drawRRect(geometry.contentRRect, _solidColorPaint..color = box.backgroundColor!);
      } else {
        context.canvas.drawRect(geometry.outer, _solidColorPaint..color = box.backgroundColor!);
      }
    }
    if ((bits & _opBgImage) != 0) {
      final painter = _ensureBgImagePainter(box.backgroundImage);
      if (painter != null) {
        painter.paint(
          context.canvas,
          geometry.contentRRect.outerRect,
          ViewBoxPainter.contentRRectHasRadius(geometry.contentRRect)
              ? (Path()..addRRect(geometry.contentRRect))
              : null,
          ImageConfiguration(
            size: geometry.outer.size,
            textDirection: _host.committedResolvedStyle.inheritedBox.direction ?? TextDirection.ltr,
          ),
        );
      }
    }
    if ((bits & _opGradient) != 0) {
      context.canvas.drawRRect(
        geometry.contentRRect,
        Paint()..shader = box.gradient!.createShader(geometry.contentRRect.outerRect),
      );
    }
    // 内阴影在背景之后、子内容之前绘制。
    if ((bits & _opShadow) != 0) {
      ViewBoxPainter.paintShadows(
        context.canvas,
        outerRRect: geometry.contentRRect,
        shadows: box.boxShadow!,
        inset: true,
      );
    }
    if ((bits & _opClip) != 0) {
      _pushClip(
        context,
        Offset.zero,
        geometry.contentRRect.outerRect,
        (geometry.radius != null && geometry.radius != BorderRadius.zero)
            ? geometry.contentRRect
            : geometry.contentRRect.outerRect,
        (ctx, _) => _host.paintContent(ctx, childOffset),
        compositing: _host.needsCompositing,
        behavior: box.clipBehavior!,
      );
    } else {
      _host.paintContent(context, childOffset);
    }
    if ((bits & _opBorder) != 0) {
      ViewBoxPainter.paintBorder(
        context.canvas,
        rect: geometry.contentRRect.outerRect,
        border: box.border!,
        borderRadius: geometry.radius,
      );
    }
    if ((bits & _opOutline) != 0) {
      ViewBoxPainter.paintOutline(
        context.canvas,
        outerRect: geometry.contentRRect.outerRect,
        outline: box.outline!,
        borderRadius: geometry.radius,
      );
    }
  }

  ContainerLayer? _pushClip(
    PaintingContext context,
    Offset offset,
    Rect bounds,
    Object geometry,
    PaintingContextCallback body, {
    required bool compositing,
    required Clip behavior,
    ContainerLayer? oldLayer,
  }) {
    return switch (geometry) {
      Path path => context.pushClipPath(
        compositing,
        offset,
        bounds,
        path,
        body,
        clipBehavior: behavior,
        oldLayer: oldLayer is ClipPathLayer ? oldLayer : null,
      ),
      RRect rect => context.pushClipRRect(
        compositing,
        offset,
        bounds,
        rect,
        body,
        clipBehavior: behavior,
        oldLayer: oldLayer is ClipRRectLayer ? oldLayer : null,
      ),
      Rect rect => context.pushClipRect(
        compositing,
        offset,
        rect,
        body,
        clipBehavior: behavior,
        oldLayer: oldLayer is ClipRectLayer ? oldLayer : null,
      ),
      _ => throw StateError('不支持的裁剪几何：${geometry.runtimeType}'),
    };
  }

  /// 保留图片流订阅，只有 image 身份改变时重建 painter。
  DecorationImagePainter? _ensureBgImagePainter(DecorationImage? image) {
    if (identical(_bgImagePainterFor, image)) return _bgImagePainter;
    _bgImagePainter?.dispose();
    _bgImagePainterFor = image;
    return _bgImagePainter = image?.createPainter(_host.markNeedsPaint);
  }
}

/// 本次绘制的共享几何；图片订阅和合成图层仍由控制器跨帧持有。
typedef _BoxGeometry = ({Rect outer, BorderRadius? radius, RRect contentRRect});

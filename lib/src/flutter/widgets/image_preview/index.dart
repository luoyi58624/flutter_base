import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../views/preview/preview_view.dart';
import '../../views/view/event/event.dart';
import '../../views/view/view.dart';
import '../image/index.dart';

part 'preview.dart';

/// 点击图片后在根覆盖层预览；不创建路由，返回操作只关闭当前预览。
class ElImagePreview extends StatelessWidget {
  /// 创建图片预览入口，省略 [images] 时只预览 [child]。
  const ElImagePreview({super.key, required this.child, this.images, this.initialIndex})
    : assert(initialIndex == null || initialIndex >= 0),
      assert(initialIndex == null || images != null && initialIndex < images.length);

  /// 缩略图片，保留它原有的加载、样式和事件配置。
  final ElImage child;

  /// 画廊图片地址；null 或空列表表示单张预览。
  final List<String>? images;

  /// 打开画廊时的索引；省略时匹配 child.src，未匹配时从第一张开始。
  final int? initialIndex;

  /// 用已有缩略图 [child] 触发单张 [image] 的覆盖层预览。
  ///
  /// [semanticLabel] 为自定义缩略图提供可访问的点击入口。
  static Widget provider({Key? key, required ImageProvider image, required Widget child, String? semanticLabel}) =>
      _ImagePreviewEntry(key: key, image: image, semanticLabel: semanticLabel, child: child);

  @override
  Widget build(BuildContext context) => _ImagePreviewEntry(
    image: child.image,
    source: child.src,
    images: images,
    initialIndex: initialIndex,
    disabled: child.event?.disabled ?? false,
    child: child,
  );
}

class _ImagePreviewEntry extends StatefulWidget {
  const _ImagePreviewEntry({
    super.key,
    required this.image,
    this.source,
    this.images,
    this.initialIndex,
    this.disabled = false,
    this.semanticLabel,
    required this.child,
  });

  final ImageProvider image;
  final String? source;
  final List<String>? images;
  final int? initialIndex;
  final bool disabled;
  final String? semanticLabel;
  final Widget child;

  @override
  State<_ImagePreviewEntry> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreviewEntry> {
  // 只登记已挂载入口，关闭画廊时可飞回同一页面的当前缩略图。
  static final _entries = <_ImagePreviewState>{};
  final _anchor = GlobalKey();
  final _viewer = GlobalKey<_PreviewState>();
  OverlayEntry? _overlay;
  _ImagePreviewState? _hiddenTarget;
  bool _hidden = false;

  int get _initialIndex {
    final images = widget.images;
    if (images == null || images.isEmpty) return 0;
    return (widget.initialIndex ?? math.max(0, images.indexOf(widget.source ?? ''))).clamp(0, images.length - 1);
  }

  Rect? _rect(OverlayState overlay) {
    final box = _anchor.currentContext?.findRenderObject();
    final root = overlay.context.findRenderObject();
    if (box is! RenderBox || root is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) return null;
    final rect = MatrixUtils.transformRect(box.getTransformTo(root), Offset.zero & box.size);
    return rect.isFinite && rect.overlaps(Offset.zero & root.size) ? rect : null;
  }

  Size? get _imageSize {
    Size? size;
    void visit(RenderObject object) {
      if (object is RenderImage && object.image != null) {
        size = Size(object.image!.width.toDouble(), object.image!.height.toDouble());
      } else if (size == null) {
        object.visitChildren(visit);
      }
    }

    final render = _anchor.currentContext?.findRenderObject();
    if (render != null) visit(render);
    return size;
  }

  @override
  void initState() {
    super.initState();
    _entries.add(this);
  }

  void _hideTarget(_ImagePreviewState? target) {
    final old = _hiddenTarget;
    if (old == target) return;
    _hiddenTarget = target;
    if (old?.mounted ?? false) old!.setState(() => old._hidden = false);
    if (target?.mounted ?? false) target!.setState(() => target._hidden = true);
  }

  void _open() {
    if (_overlay != null || widget.disabled) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final addresses = List<String>.unmodifiable(widget.images ?? const []);
    final initial = _initialIndex;
    final images = addresses.isEmpty
        ? [widget.image]
        : [
            for (var i = 0; i < addresses.length; i++)
              if (i == initial && addresses[i] == widget.source) widget.image else ElImage(addresses[i]).image,
          ];
    final origin = _rect(overlay);
    final imageSize = _imageSize;
    final route = ModalRoute.of(context);
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    final direction = Directionality.of(context);
    final desktop = switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
    _hideTarget(this);
    setState(() {
      _overlay = OverlayEntry(
        builder: (_) => Positioned.fill(
          child: themes.wrap(
            Directionality(
              textDirection: direction,
              child: _Preview(
                key: _viewer,
                images: images,
                initialIndex: initial,
                origin: origin,
                imageSize: imageSize,
                desktop: desktop,
                onClosed: _remove,
                destination: (index) {
                  _ImagePreviewState? target;
                  if (addresses.isEmpty) {
                    if (mounted) target = this;
                  } else {
                    for (final entry in _entries) {
                      if (entry.mounted &&
                          ModalRoute.of(entry.context) == route &&
                          listEquals(entry.widget.images, addresses) &&
                          entry._initialIndex == index &&
                          entry.widget.source == addresses[index]) {
                        target = entry;
                        break;
                      }
                    }
                  }
                  final rect = target?._rect(overlay);
                  _hideTarget(rect == null ? null : target);
                  return rect;
                },
              ),
            ),
          ),
        ),
      );
    });
    overlay.insert(_overlay!);
  }

  void _remove() {
    final overlay = _overlay;
    _overlay = null;
    overlay?.remove();
    overlay?.dispose();
    _hideTarget(null);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entries.remove(this);
    _overlay?.remove();
    _overlay?.dispose();
    final hidden = _hiddenTarget;
    // 入口卸载时释放其他缩略图的隐藏状态，避开树销毁期间触发重建。
    if (hidden != null && hidden != this) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hidden.mounted) hidden.setState(() => hidden._hidden = false);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trigger = ElView(
      event: ElEvent(
        onTap: (event) {
          if (!event.defaultPrevented) _open();
        },
      ),
      child: RepaintBoundary(
        key: _anchor,
        child: Opacity(opacity: _hidden ? 0 : 1, child: widget.child),
      ),
    );
    final label = widget.semanticLabel;
    return PopScope(
      canPop: _overlay == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _viewer.currentState?.close();
      },
      child: label == null
          ? trigger
          : Semantics(label: label, button: true, excludeSemantics: true, onTap: _open, child: trigger),
    );
  }
}

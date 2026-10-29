import 'package:flutter/widgets.dart';

/// 用官方 Overlay 承载测试页面，更新时保留同一个页面 entry。
class ElTestOverlay extends StatefulWidget {
  /// 创建只含一个页面 entry 的测试容器。
  const ElTestOverlay({super.key, required this.child, this.clipBehavior = Clip.hardEdge});

  /// 原位保留的测试内容。
  final Widget child;

  /// 官方 Overlay 的裁剪策略。
  final Clip clipBehavior;

  @override
  State<ElTestOverlay> createState() => _TestOverlayState();
}

class _TestOverlayState extends State<ElTestOverlay> {
  late final _page = OverlayEntry(canSizeOverlay: true, builder: (_) => widget.child);

  @override
  void didUpdateWidget(ElTestOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_page], clipBehavior: widget.clipBehavior);

  @override
  void dispose() {
    _page.remove();
    _page.dispose();
    super.dispose();
  }
}

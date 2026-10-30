import 'dart:async';

import 'package:flutter/widgets.dart';

/// Element Plus 无限滚动。
///
/// 官方是挂在滚动容器上的指令，这里包成组件：把滚动视图放进 [child]，
/// 把它的 [controller] 交进来即可。
///
/// ```dart
/// ElInfiniteScroll(
///   controller: controller,
///   onLoad: () async => loadNextPage(),
///   child: ElScrollView(controller: controller, children: rows),
/// )
/// ```
class ElInfiniteScroll extends StatefulWidget {
  const ElInfiniteScroll({
    super.key,
    required this.controller,
    required this.onLoad,
    required this.child,
    this.distance = 0,
    this.disabled = false,
    this.delay = const Duration(milliseconds: 200),
    this.immediate = true,
  });

  /// 被观察的滚动控制器
  final ScrollController controller;

  /// 触底回调；返回 Future 时会等它完成才允许下一次触发
  final FutureOr<void> Function() onLoad;

  final Widget child;

  /// 距底部多少像素开始触发（官方 infinite-scroll-distance）
  final double distance;

  /// 关掉加载（数据加载完时置 true，官方口径）
  final bool disabled;

  /// 触发防抖时长（官方 infinite-scroll-delay）
  final Duration delay;

  /// 挂载时立刻检查一次（官方 infinite-scroll-immediate）：内容不满一屏就先加载。
  /// 只查一次——加载后不自动续补，与官方指令一致；要继续加载靠用户滚动或调用方自行安排
  final bool immediate;

  @override
  State<ElInfiniteScroll> createState() => _InfiniteScrollState();
}

class _InfiniteScrollState extends State<ElInfiniteScroll> {
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    if (widget.immediate) {
      // 挂载帧还没有布局结果，等一帧再判断是否满屏
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schedule();
      });
    }
  }

  @override
  void didUpdateWidget(ElInfiniteScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    // 从禁用恢复时重新判断一次，避免刚好停在底部却再也不触发
    if (oldWidget.disabled && !widget.disabled) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => _schedule();

  /// 是否已进入触发区（含 [ElInfiniteScroll.distance] 提前量）
  bool get _reached {
    if (!widget.controller.hasClients) return false;
    final position = widget.controller.position;
    return position.maxScrollExtent - position.pixels <= widget.distance;
  }

  void _schedule() {
    if (widget.disabled || _loading || !_reached) return;
    _timer?.cancel();
    _timer = Timer(widget.delay, _load);
  }

  Future<void> _load() async {
    if (!mounted || widget.disabled || _loading || !_reached) return;
    _loading = true;
    try {
      await widget.onLoad();
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

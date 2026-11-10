import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import '../../../dart/gen/index.dart' show $absent;
import '../../scroll/refresh/android_refresher.dart';
import '../../scroll/refresh/ios_refresher.dart';
import '../../scroll/refresh/refresher.dart';
import '../scroll/scrollbar/android_scroll_bar.dart';
import '../scroll/scrollbar/ios_scroll_bar.dart';
import '../scroll/scrollbar/mac_scroll_bar.dart';
import '../scroll/scrollbar/scrollbar_base.dart';
import '../scroll/scrollbar/window_scroll_bar.dart';
import '../../scroll/smooth/smooth_scroll.dart';

/// el_ui 核心 View 系统的环境级默认实现提供器。
class ElViewProvider extends StatelessWidget {
  /// 创建 View 环境提供器。
  const ElViewProvider({
    super.key,
    this.scrollbarBuilder,
    this.refresherBuilder,
    this.smoothScrollBuilder = _adaptiveSmoothScrollBuilder,
    required this.child,
  });

  /// 覆写当前子树的滚动条实现；null 表示继承祖先或使用 el_ui 默认。
  final ElScrollbar? Function(BuildContext context)? scrollbarBuilder;

  /// 覆写当前子树的下拉刷新实现；null 表示继承祖先或使用 el_ui 默认。
  final ElRefresher? Function(BuildContext context)? refresherBuilder;

  /// 覆写平滑算法；不传或回调返回 [$absent] 时继承祖先或平台默认。
  ///
  /// 显式传 null 或回调返回 null 时关闭，返回 [ElSmoothScroll] 时使用指定算法。
  final Object? Function(BuildContext context)? smoothScrollBuilder;

  /// 子树。
  final Widget child;

  /// 三个读取入口共用依赖注册，仍仅订阅指定配置。
  static _ElViewProviderScope? _scopeOf(BuildContext context, _ElViewProviderAspect aspect) =>
      InheritedModel.inheritFrom<_ElViewProviderScope>(context, aspect: aspect);

  /// 获取当前作用域生效的滚动条实现。
  ///
  /// 未找到祖先覆写时，按当前平台返回 el_ui 内置默认实现。
  static ElScrollbar scrollbarOf(BuildContext context) {
    final inherited = _scopeOf(context, _ElViewProviderAspect.scrollbar);
    if (inherited != null) return inherited.scrollbar;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.fuchsia => const ElAndroidScrollBar(),
      TargetPlatform.iOS => const ElIosScrollBar(),
      TargetPlatform.windows => const ElWindowScrollBar(),
      TargetPlatform.linux || TargetPlatform.macOS => const ElMacScrollBar(),
    };
  }

  /// 获取当前作用域生效的下拉刷新实现。
  ///
  /// 未找到祖先覆写时，按当前平台返回 el_ui 内置默认实现。
  static ElRefresher refresherOf(BuildContext context) {
    final inherited = _scopeOf(context, _ElViewProviderAspect.refresher);
    if (inherited != null) return inherited.refresher;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.fuchsia => const ElAndroidRefresher(),
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => const ElIosRefresher(),
    };
  }

  /// 获取当前作用域生效的平滑滚动算法。
  ///
  /// 未找到祖先覆写时使用 el_ui 平台默认；默认直滚的平台返回 null。
  static ElSmoothScroll? smoothScrollOf(BuildContext context) {
    final inherited = _scopeOf(context, _ElViewProviderAspect.smoothScroll);
    if (inherited != null) return inherited.smoothScroll;
    return resolveDefaultSmoothScroll();
  }

  @override
  Widget build(BuildContext context) {
    final scrollbar = scrollbarBuilder?.call(context) ?? scrollbarOf(context);
    final refresher = refresherBuilder?.call(context) ?? refresherOf(context);
    final configuredSmoothScroll = smoothScrollBuilder?.call(context);
    final smoothScroll = identical(configuredSmoothScroll, $absent)
        ? smoothScrollOf(context)
        : configuredSmoothScroll as ElSmoothScroll?;

    // Scope 结构固定；builder 在运行时从具体值切回 null 时只改变继承结果，
    // 不插拔节点。InheritedModel 让三类消费者只订阅自己关心的配置。
    return _ElViewProviderScope(scrollbar: scrollbar, refresher: refresher, smoothScroll: smoothScroll, child: child);
  }
}

// 默认回调保留 Builder 的上下文类型推断，真正的自适应值仍是统一占位符。
Object? _adaptiveSmoothScrollBuilder(BuildContext _) => $absent;

enum _ElViewProviderAspect { scrollbar, refresher, smoothScroll }

class _ElViewProviderScope extends InheritedModel<_ElViewProviderAspect> {
  const _ElViewProviderScope({
    required this.scrollbar,
    required this.refresher,
    required this.smoothScroll,
    required super.child,
  });

  final ElScrollbar scrollbar;
  final ElRefresher refresher;
  final ElSmoothScroll? smoothScroll;

  @override
  bool updateShouldNotify(_ElViewProviderScope oldWidget) =>
      oldWidget.scrollbar != scrollbar || oldWidget.refresher != refresher || oldWidget.smoothScroll != smoothScroll;

  @override
  bool updateShouldNotifyDependent(_ElViewProviderScope oldWidget, Set<_ElViewProviderAspect> dependencies) {
    return (dependencies.contains(_ElViewProviderAspect.scrollbar) && oldWidget.scrollbar != scrollbar) ||
        (dependencies.contains(_ElViewProviderAspect.refresher) && oldWidget.refresher != refresher) ||
        (dependencies.contains(_ElViewProviderAspect.smoothScroll) && oldWidget.smoothScroll != smoothScroll);
  }
}

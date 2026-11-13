part of 'index.dart';

/// 顶部消息服务。
extension ElMessageExt on El {
  static final _service = ElMessageService._();

  /// 在窗口顶部显示消息，多条消息同时存在，各自计时关闭。
  ElMessageService get message => _service;
}

/// 顶部消息：同一 Overlay 的消息共用一层，由品牌的 messageStack 排布。
final class ElMessageService {
  ElMessageService._();

  final _stacks = <OverlayState, _MessageStack>{};

  /// 显示一条消息，退场移除后完成；`duration` 不大于零时保留到用户关闭，指针悬停期间暂停计时。
  Future<void> show(
    Object message, {
    BuildContext? context,
    ElThemeType type = .info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context != null && !context.mounted) return Future.value();
    final overlay = context == null
        ? el.navigatorKey.currentState?.overlay
        : Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return Future.value();
    final themes = context == null ? null : InheritedTheme.capture(from: context, to: overlay.context);
    final stack = _stacks[overlay] ??= _MessageStack(overlay, () => _stacks.remove(overlay));
    return stack.add(message, type, duration, themes);
  }
}

final class _MessageStack {
  _MessageStack(OverlayState overlay, this.onEmpty) {
    entry = OverlayEntry(
      builder: (context) {
        final children = [for (final message in messages) message.widget];
        final layout = Builder(builder: (context) => _layoutOf(context)(context, children));
        return Positioned.fill(child: themes?.wrap(layout) ?? layout);
      },
    );
    // 承载的 Overlay 卸载时一并结清。
    entry.addListener(() {
      if (!entry.mounted) {
        for (final message in messages.toList()) {
          message.close();
        }
      }
    });
    overlay.insert(entry);
  }

  late final OverlayEntry entry;

  /// 最近一次调用处的主题，排布容器跟随当前品牌，例如从桌面布局切到移动布局。
  CapturedThemes? themes;
  final VoidCallback onEmpty;
  final messages = <_Message>[];

  static Widget Function(BuildContext, List<Widget>) _layoutOf(BuildContext context) {
    final layout = ElComponentProvider.of(context).messageStack;
    if (layout == null) throw FlutterError('ElMessage 的 messageStack 未在 ElComponentProvider 中登记实现。');
    return layout;
  }

  Future<void> add(Object content, ElThemeType type, Duration duration, CapturedThemes? themes) {
    final message = _Message(this, content, type, duration, themes);
    if (themes != null) this.themes = themes;
    messages.add(message);
    entry.markNeedsBuild();
    return message.removed;
  }

  void remove(_Message message) {
    messages.remove(message);
    if (messages.isNotEmpty) return entry.markNeedsBuild();
    entry
      ..remove()
      ..dispose();
    onEmpty();
  }
}

final class _Message {
  _Message(this.stack, Object content, ElThemeType type, this.duration, CapturedThemes? themes) {
    final child = transitions.wrap(ElMessage(type: type, onClose: close, child: content));
    // 全局键：排布容器随调用处的品牌换层时，消息连同动画状态迁移过去，不重新进场。
    widget = KeyedSubtree(
      key: GlobalObjectKey(this),
      child: MouseRegion(
        // 只在消息自身被命中时生效，品牌布局留出的空白不拦截事件。
        hitTestBehavior: .deferToChild,
        onEnter: (_) => timer?.cancel(),
        onExit: (_) => _countdown(),
        child: Semantics(liveRegion: true, child: themes?.wrap(child) ?? child),
      ),
    );
    _countdown();
  }

  final _MessageStack stack;
  final Duration duration;
  final transitions = OverlayTransitions();
  final _removed = Completer<void>();
  late final Widget widget;
  Timer? timer;
  Future<void>? _closing;

  Future<void> get removed => _removed.future;

  void _countdown() {
    timer?.cancel();
    if (duration > Duration.zero && _closing == null) timer = Timer(duration, close);
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    timer?.cancel();
    await transitions.reverse();
    stack.remove(this);
    _removed.complete();
  }
}

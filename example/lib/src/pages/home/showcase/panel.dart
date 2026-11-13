import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport, RenderSliver;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_base/mobile.dart';

/// 展示页共享的锚点和可用宽度，布局按页面而非单张卡片判断断点。
class ShowcaseScope extends InheritedWidget {
  /// 创建本页展示环境。
  const ShowcaseScope({
    super.key,
    required this.width,
    required this.anchors,
    required this.onNavigate,
    this.scrollController,
    required super.child,
  });

  /// 页面可用宽度。
  final double width;

  /// 小节的稳定定位节点。
  final Map<String, GlobalKey> anchors;

  /// 滚动到指定小节。
  final ValueChanged<String> onNavigate;

  /// 首页真实滚动位置，用于暂停离屏的演示动画。
  final ScrollController? scrollController;

  /// 读取当前展示环境。
  static ShowcaseScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShowcaseScope>()!;

  /// 手机采用单列。
  bool get mobile => width <= 760;
  @override
  bool updateShouldNotify(ShowcaseScope oldWidget) =>
      width != oldWidget.width || scrollController != oldWidget.scrollController;
}

/// 原稿中的独立演示卡片。
class ShowcasePanel extends StatelessWidget {
  /// 标题、说明和演示内容使用统一留白。
  const ShowcasePanel({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.anchor,
    this.padding,
  });

  /// 卡片标题。
  final String title;

  /// 简短场景说明。
  final String description;

  /// 演示内容。
  final Widget child;

  /// 可选章节锚点。
  final String? anchor;

  /// 特殊卡片可调整内容留白。
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    final mobile = ShowcaseScope.of(context).mobile;
    final t = context.elTheme;
    return ElCard(
      key: anchor == null ? null : ShowcaseScope.of(context).anchors[anchor],
      style: ElStyle(
        width: '100%',
        padding: padding ?? (mobile ? .fromLTRB(22, 24, 22, 25) : .fromLTRB(29, 28, 29, 29)),
        borderRadius: .circular(mobile ? 26 : 30),
        border: .all(borderColor: t.borderColor.withValues(alpha: .65)),
      ).withShadow(type: .floating, level: ElLevelType.md.shadow(context)),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 20, height: 1.35, letterSpacing: -.55, fontWeight: .w600, color: t.textColor),
          ),
          SizedBox(height: 7),
          Text(description, style: TextStyle(fontSize: 13, height: 1.55, color: t.textSecondary)),
          SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

/// 按原稿断点排列演示卡片，窄屏保留完整内容自然高度。
class ShowcaseGrid extends StatelessWidget {
  /// columns 指定宽屏列数，手机默认单列。
  const ShowcaseGrid({super.key, required this.children, this.columns = 2, this.mobileColumns = 1, this.gap});

  /// 演示卡片。
  final List<Widget> children;

  /// 宽屏列数。
  final int columns;

  /// 窄屏列数。
  final int mobileColumns;

  /// 覆盖卡片间距。
  final double? gap;
  @override
  Widget build(BuildContext context) {
    final mobile = ShowcaseScope.of(context).mobile;
    final count = mobile ? mobileColumns : columns;
    final space = gap ?? (mobile ? 16 : 18);
    // Wrap 只改变换行位置，卡片在元素树中的父级与顺序保持不变。
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: space,
          runSpacing: space,
          children: [
            for (final child in children)
              SizedBox(
                width: (constraints.maxWidth - space * (count - 1)) / count,
                child: RepaintBoundary(child: child),
              ),
          ],
        );
      },
    );
  }
}

/// 按自然高度排列展示分组，隔离各组重绘以复用静态内容。
Widget showcaseColumn(List<Widget> children, {double gap = 16}) => Column(
  mainAxisSize: .min,
  crossAxisAlignment: .stretch,
  spacing: gap,
  children: [for (final child in children) RepaintBoundary(child: child)],
);

/// 读取布局坐标前确认条目仍在视口的布局范围内。
bool showcaseIsLaidOut(RenderObject render) {
  if (!render.attached) return false;
  for (RenderObject child = render; child.parent != null; child = child.parent!) {
    final parent = child.parent!;
    if (parent is RenderSliver && parent.childScrollOffset(child) == null) return false;
  }
  return true;
}

/// 无限进度和播放示例仅在真正进入视口时运行动画与演示计时器。
class ShowcaseMotion extends HookWidget {
  /// 保留子树状态，只切换 TickerMode。
  const ShowcaseMotion({super.key, required this.child});

  /// 含动画或演示计时器的内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = ShowcaseScope.of(context), scroll = scope.scrollController;
    final key = useMemoized(GlobalKey.new);
    final visible = useState(scroll == null), queued = useRef(false);
    void schedule() {
      if (queued.value) return;
      queued.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        queued.value = false;
        if (!context.mounted || scroll == null || !scroll.hasClients) return;
        final box = key.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize || !showcaseIsLaidOut(box)) {
          visible.value = false;
          return;
        }
        final start = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
        visible.value =
            start < scroll.offset + scroll.position.viewportDimension && start + box.size.height > scroll.offset;
      });
    }

    useEffect(() {
      scroll?.addListener(schedule);
      schedule();
      return () => scroll?.removeListener(schedule);
    }, [scroll, scope.width, MediaQuery.textScalerOf(context)]);
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        schedule();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: TickerMode(
          enabled: visible.value,
          child: KeyedSubtree(key: key, child: child),
        ),
      ),
    );
  }
}

/// 分区标题与定位链接。
class ShowcaseSection extends StatelessWidget {
  /// 编号、标题和说明对应设计稿五个主分区。
  const ShowcaseSection({
    super.key,
    required this.id,
    required this.number,
    required this.category,
    required this.title,
    required this.description,
    this.links = const {},
  });

  /// 主分区身份。
  final String id;

  /// 分区编号。
  final String number;

  /// 目录名称。
  final String category;

  /// 大标题。
  final String title;

  /// 辅助说明。
  final String description;

  /// 子节链接，键为定位身份。
  final Map<String, String> links;

  @override
  Widget build(BuildContext context) {
    final scope = ShowcaseScope.of(context), t = context.elTheme;
    return Column(
      crossAxisAlignment: .stretch,
      mainAxisSize: .min,
      children: [
        Text(
          '$number / $category',
          style: TextStyle(color: t.primary, fontSize: 11, fontWeight: .w700, letterSpacing: .65),
        ),
        SizedBox(height: 5),
        Text(
          title,
          style: TextStyle(
            fontSize: (scope.width * .026).clamp(24, 33),
            height: 1.25,
            fontWeight: .w700,
            letterSpacing: -.6,
            color: t.textColor,
          ),
        ),
        SizedBox(height: 7),
        demoHint(context, description, size: 14, height: 1.6),
        SizedBox(height: 20),
        if (links.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final link in links.entries)
                ElButton(
                  variant: .outline,
                  style: ElStyle(
                    minHeight: scope.mobile ? 44 : 36,
                    padding: .symmetric(horizontal: 11),
                    borderRadius: .circular(8),
                    fontSize: 13,
                    color: t.textSecondary,
                  ),
                  onPressed: () => scope.onNavigate(link.key),
                  child: link.value,
                ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// 演示项的辅助文字。
Widget demoHint(BuildContext context, String text, {double size = 12, double height = 1.75}) => Text(
  text,
  style: TextStyle(fontSize: size, height: height, color: context.elTheme.textSecondary),
);

/// 表单的简短标签。
Widget demoLabel(BuildContext context, String text) => Text(
  text,
  style: TextStyle(fontSize: 13, height: 1.5, fontWeight: .w500, color: context.elTheme.textColor),
);

/// 演示内容按自然高度纵向排列。
Widget demoColumn(List<Widget> children, {double gap = 16}) =>
    Column(mainAxisSize: .min, crossAxisAlignment: .stretch, spacing: gap, children: children);

/// 操作在空间不足时换行。
Widget demoActions(List<Widget> children, {double gap = 10}) =>
    Wrap(spacing: gap, runSpacing: gap, crossAxisAlignment: .center, children: children);

/// 使用品牌图标尺寸和颜色。
Widget demoIcon(Widget icon, {double size = 20, Color? color}) => ElView(
  style: ElStyle(iconSize: size, iconColor: color),
  child: icon,
);

/// 首页的一张演示卡或一行卡片，只持有构建方法。
class ShowcaseItem {
  /// 创建按需构建的演示项，局部 Hook 随该项卸载。
  ShowcaseItem(this._builder, {String? anchor, this.gap = 22})
    : _anchor = anchor,
      anchors = [if (anchor != null) anchor];

  ShowcaseItem._row(this._builder, this.anchors, this.gap) : _anchor = null;

  final WidgetBuilder _builder;
  final String? _anchor;

  /// 此项可定位的锚点。
  final List<String> anchors;

  /// 此项与下一项之间的间距。
  final double gap;

  /// 构建本项，锚点随对应卡片一起挂载。
  Widget build(BuildContext context) => HookBuilder(key: ShowcaseScope.of(context).anchors[_anchor], builder: _builder);

  /// 手机逐卡构建，宽屏把同一行的卡片放在一个滚动项内。
  static Iterable<ShowcaseItem> rows(List<ShowcaseItem> cards, {required int columns, double? gap}) sync* {
    if (columns == 1) {
      yield* cards;
      return;
    }
    for (var start = 0; start < cards.length; start += columns) {
      final row = cards.skip(start).take(columns).toList();
      yield ShowcaseItem._row(
        (context) => ShowcaseGrid(columns: columns, gap: gap, children: [for (final card in row) card.build(context)]),
        [for (final card in row) ...card.anchors],
        gap ?? 18,
      );
    }
  }
}

/// 显示演示结果。
void demoNotify(BuildContext context, String message) => el.toast.show(message, context: context);

/// 打开首页两处入口共用的分享面板。
Future<String?> demoShare(BuildContext context) async {
  final action = await el.dialog.show<String>(
    context,
    placement: .bottom,
    title: '分享这份灵感',
    showClose: false,
    child: Builder(
      builder: (context) => ElListGroup(
        children: [
          for (final (label, value, icon) in [
            ('复制链接', 'copy', ElMobileIcons.copy),
            ('收藏到本地', 'favorite', ElMobileIcons.heart),
            ('稍后查看', 'later', ElMobileIcons.clock),
          ])
            ElListTile(title: label, leading: icon, onTap: () => Navigator.of(context).pop(value)),
        ],
      ),
    ),
    footer: demoPopupActions(),
  );
  if (!context.mounted || action == null) return null;
  if (action == 'copy') await Clipboard.setData(ClipboardData(text: 'flutter-base://home'));
  if (action == 'favorite') Obs.localStorage.setItem('showcase.liked', true);
  if (action == 'later') Obs.localStorage.setItem('showcase.later', true);
  if (!context.mounted) return null;
  demoNotify(context, switch (action) {
    'copy' => '链接已复制',
    'favorite' => '已收藏到本地',
    _ => '已加入稍后查看',
  });
  return action;
}

/// 首页确认与提醒共用 Web 的通栏操作区，仍通过现有弹层 API 返回选择结果。
Future<bool?> demoDialog(
  BuildContext context, {
  String title = '确认保存更改？',
  String message = '保存后将同步更新你的设置。你也可以稍后再进行调整。',
  String confirm = '确认保存',
  bool danger = false,
  bool single = false,
  ElPopupPlacement placement = .bottom,
}) => el.dialog.show<bool>(
  context,
  title: title,
  placement: placement,
  child: Text(
    message,
    textAlign: placement == .center ? .center : .left,
    style: TextStyle(fontSize: 15, height: 1.9, color: context.elTheme.textSecondary),
  ),
  footer: demoPopupActions<bool>(
    cancel: single ? null : '取消',
    confirm: confirm,
    onConfirm: () => true,
    cancelResult: false,
    danger: danger,
  ),
);

/// 创建贴合面板底部的通栏动作，并通过当前路由返回结果。
Widget demoPopupActions<T extends Object?>({
  String? cancel = '取消',
  String? confirm,
  T? cancelResult,
  T? Function()? onConfirm,
  bool danger = false,
}) => Builder(
  builder: (context) {
    final t = context.elTheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    Widget action(String label, bool accepted) => Expanded(
      child: ElButton(
        variant: .text,
        style: ElStyle(
          width: '100%',
          minHeight: 66,
          padding: .fromLTRB(16, 18, 16, 24 + safeBottom),
          borderRadius: .zero,
          fontSize: 16,
          lineHeight: 1.5,
          color: accepted && danger ? t.error : t.primary,
          transition: [ElTransition.field(.backgroundColor, Duration(milliseconds: 140))],
          onTap: ElStyle(backgroundColor: t.press, transform: ElTransform.scale(1), transition: []),
        ),
        child: label,
        onPressed: () => Navigator.of(context).pop(accepted ? onConfirm?.call() : cancelResult),
      ),
    );
    return Stack(
      children: [
        Row(children: [if (cancel != null) action(cancel, false), if (confirm != null) action(confirm, true)]),
        if (cancel != null && confirm != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: .topCenter,
                child: Padding(
                  padding: .only(top: 20),
                  child: ElView(style: ElStyle(width: 1, height: 20, backgroundColor: t.borderColor)),
                ),
              ),
            ),
          ),
      ],
    );
  },
);

/// 使用原稿图片资源。
const showcaseLake = 'assets/showcase/lake.png';

/// 使用原稿头像资源。
const showcaseAvatar = 'assets/showcase/avatar-lan.png';

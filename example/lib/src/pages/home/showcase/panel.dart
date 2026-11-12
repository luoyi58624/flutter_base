import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
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
        boxShadow: t.shadowMd,
      ),
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
class ShowcaseGrid extends HookWidget {
  /// columns 指定宽屏列数，手机默认单列。
  const ShowcaseGrid({super.key, required this.children, this.columns = 2, this.mobileColumns = 1, this.gap})
    : _sliver = false;

  /// 顶层卡片按行交给文档 Sliver 裁剪，保留所有卡片的交互状态。
  const ShowcaseGrid.sliver({super.key, required this.children, this.columns = 2, this.mobileColumns = 1, this.gap})
    : _sliver = true;

  final bool _sliver;

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
    // 跨断点换行时，卡片中的局部状态仍留在原实例。
    final keys = useMemoized(() => _sliver ? List.generate(children.length, (_) => GlobalKey()) : <GlobalKey>[], [
      _sliver,
      children.length,
    ]);
    if (_sliver) {
      return showcaseSliverList([
        for (var start = 0; start < children.length; start += count)
          LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: .start,
              spacing: space,
              children: [
                for (var index = start; index < start + count && index < children.length; index++)
                  SizedBox(
                    width: (constraints.maxWidth - space * (count - 1)) / count,
                    child: KeyedSubtree(key: keys[index], child: children[index]),
                  ),
              ],
            ),
          ),
      ], gap: space);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: space,
          runSpacing: space,
          children: [
            for (final child in children)
              SizedBox(width: (constraints.maxWidth - space * (count - 1)) / count, child: child),
          ],
        );
      },
    );
  }
}

/// 按原有间距串起文档 Sliver，裁剪粒度落在每张卡片或每行卡片。
class ShowcaseSlivers extends StatelessWidget {
  /// 子项均为 Sliver，普通内容可通过 showcaseSliver 转接。
  const ShowcaseSlivers(this.children, {super.key, this.gap = 22});

  /// 按展示顺序排列的分组。
  final List<Widget> children;

  /// 相邻分组的间距。
  final double gap;

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) SliverToBoxAdapter(child: SizedBox(height: gap)),
        children[index],
      ],
    ],
  );
}

/// 常驻内容交给已有文档 Sliver 排版；静态行随滚动复用绘制结果。
Widget showcaseSliverList(List<Widget> children, {double gap = 16}) => ElSliverList(
  stretch: true,
  spacing: gap,
  children: [for (final child in children) RepaintBoundary(child: child)],
);

/// 将单个普通展示块接入文档滚动。
Widget showcaseSliver(Widget child) => showcaseSliverList([child]);

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
        if (box is! RenderBox || !box.attached || !box.hasSize) return;
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
    required this.child,
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

  /// 按卡片行划分的分区 Sliver。
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scope = ShowcaseScope.of(context), t = context.elTheme;
    final heading = Column(
      key: scope.anchors[id],
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
    return SliverMainAxisGroup(slivers: [showcaseSliver(heading), child]);
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

/// 在章节内登记锚点。
Widget demoAnchor(BuildContext context, String id, Widget child) =>
    KeyedSubtree(key: ShowcaseScope.of(context).anchors[id], child: child);

/// 显示演示结果。
void demoNotify(BuildContext context, String message) => el.toast(context, message, icon: ElMobileIcons.check);

/// 首页确认与提醒共用 Web 的通栏操作区，仍通过现有弹层 API 返回选择结果。
Future<bool?> demoDialog(
  BuildContext context, {
  String title = '确认保存更改？',
  String message = '保存后将同步更新你的设置。你也可以稍后再进行调整。',
  String confirm = '确认保存',
  bool danger = false,
  bool single = false,
  ElPopupPlacement placement = .bottom,
}) => el.dialog<bool>(
  context,
  title: title,
  placement: placement,
  child: Text(
    message,
    textAlign: placement == .center ? .center : .left,
    style: TextStyle(fontSize: 15, height: 1.9, color: context.elTheme.textSecondary),
  ),
  footer: Builder(
    builder: (context) {
      final t = context.elTheme;
      Widget action(String label, bool accepted) => Expanded(
        child: ElButton(
          variant: .text,
          style: ElStyle(
            width: '100%',
            minHeight: 66,
            padding: .fromLTRB(16, 18, 16, 24),
            borderRadius: .zero,
            fontSize: 16,
            lineHeight: 1.5,
            color: accepted && danger ? t.error : t.primary,
            transition: [ElTransition.field(.backgroundColor, Duration(milliseconds: 140))],
            onTap: ElStyle(backgroundColor: t.press, transition: []),
          ),
          child: label,
          onPressed: () => Navigator.of(context).pop(accepted),
        ),
      );
      return Stack(
        children: [
          Row(children: [if (!single) action('取消', false), action(confirm, true)]),
          if (!single)
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
  ),
);

/// 使用原稿图片资源。
const showcaseLake = 'assets/showcase/lake.png';

/// 使用原稿头像资源。
const showcaseAvatar = 'assets/showcase/avatar-lan.png';

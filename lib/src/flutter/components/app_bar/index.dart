import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 页面导航及滚动效果参数的公共声明。
class ElAppBar extends StatelessWidget {
  /// 普通固定导航，标题默认靠起边。
  const ElAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.showBackButton = true,
    this.centerTitle = false,
    this.backgroundColor,
    this.color,
    this.border = true,
    this.maxWidth,
    this.zIndex = 9,
  }) : isLargeTitle = false,
       isCollapsible = false,
       isFading = false,
       fadeTitle = false,
       initialColor = null,
       fadeStart = 24,
       fadeDistance = 160,
       fadeCurve = Curves.easeInOut,
       followDelta = false,
       collapseVelocity = null,
       expandVelocity = null,
       collapseOffset = null,
       scale = false,
       fade = false,
       snap = false,
       search = null;

  /// 大标题导航；关闭 scale 并打开 fade 即为非缩放的标题淡入淡出。
  const ElAppBar.largeTitle({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.showBackButton = true,
    this.centerTitle = false,
    this.backgroundColor,
    this.color,
    this.border = true,
    this.maxWidth,
    this.zIndex = 9,
    this.scale = true,
    this.fade = false,
    this.snap = true,
    this.search,
  }) : isLargeTitle = true,
       isCollapsible = false,
       isFading = false,
       fadeTitle = false,
       initialColor = null,
       fadeStart = 24,
       fadeDistance = 160,
       fadeCurve = Curves.easeInOut,
       followDelta = false,
       collapseVelocity = null,
       expandVelocity = null,
       collapseOffset = null;

  /// 悬浮导航，默认按方向显隐；可改用速度或位置阈值，followDelta 控制跟手平移。
  const ElAppBar.collapse({
    super.key,
    required this.title,
    this.followDelta = false,
    this.collapseVelocity,
    this.expandVelocity,
    this.collapseOffset,
    this.leading,
    this.actions = const [],
    this.showBackButton = true,
    this.centerTitle = false,
    this.backgroundColor,
    this.color,
    this.border = true,
    this.maxWidth,
    this.zIndex = 9,
  }) : assert(
         !followDelta || (collapseVelocity == null && expandVelocity == null),
         'followDelta 不能与速度阈值组合。',
       ),
       assert(
         collapseOffset == null ||
             (collapseVelocity == null && expandVelocity == null),
         '速度阈值与 collapseOffset 不能组合。',
       ),
       assert(
         collapseVelocity == null ||
             (collapseVelocity >= 0 && collapseVelocity < double.infinity),
         'collapseVelocity 必须有限且非负。',
       ),
       assert(
         expandVelocity == null ||
             (expandVelocity >= 0 && expandVelocity < double.infinity),
         'expandVelocity 必须有限且非负。',
       ),
       assert(
         collapseOffset == null ||
             (collapseOffset >= 0 && collapseOffset < double.infinity),
         'collapseOffset 必须有限且非负。',
       ),
       isCollapsible = true,
       isFading = false,
       fadeTitle = false,
       initialColor = null,
       fadeStart = 24,
       fadeDistance = 160,
       fadeCurve = Curves.easeInOut,
       isLargeTitle = false,
       snap = false,
       scale = false,
       fade = false,
       search = null;

  /// 滚动渐显导航，正文延伸到透明导航后方；标题默认常显，背景和底边线随滚动渐入。
  const ElAppBar.fade({
    super.key,
    required this.title,
    this.fadeTitle = false,
    this.initialColor,
    this.fadeStart = 24,
    this.fadeDistance = 160,
    this.fadeCurve = Curves.easeInOut,
    this.leading,
    this.actions = const [],
    this.showBackButton = true,
    this.centerTitle = false,
    this.backgroundColor,
    this.color,
    this.border = true,
    this.maxWidth,
    this.zIndex = 9,
  }) : assert(
         fadeStart >= 0 && fadeStart < double.infinity,
         'fadeStart 必须有限且非负。',
       ),
       assert(
         fadeDistance > 0 && fadeDistance < double.infinity,
         'fadeDistance 必须有限且大于零。',
       ),
       isFading = true,
       isCollapsible = false,
       isLargeTitle = false,
       followDelta = false,
       collapseVelocity = null,
       expandVelocity = null,
       collapseOffset = null,
       scale = false,
       fade = false,
       snap = false,
       search = null;

  /// 标题内容，文字与 Widget 均可，大小标题共享内容并各自继承字号。
  final Object title;

  /// 自定义起边组件；省略时优先使用抽屉菜单按钮，再按 showBackButton 显示返回按钮。
  final Widget? leading;

  /// 导航末端动作，排列和反馈由品牌实现提供。
  final List<Widget> actions;

  /// 是否显示默认返回按钮；根页面可关闭。
  final bool showBackButton;

  /// 紧凑导航标题是否居中，不影响展开的大标题。
  final bool centerTitle;

  /// 导航底色，省略时读取 ElThemeData.appbarColor。
  final Color? backgroundColor;

  /// 标题和默认返回图标颜色，省略时继承页面颜色。
  final Color? color;

  /// 是否显示底部分隔线；大标题随折叠渐入，搜索框收起后接续展开。
  final bool border;

  /// 可选内容最大宽度，用于与宽屏正文对齐。
  final double? maxWidth;

  /// 导航显示层级，按页面模式解释：
  /// body 模式与滚动条在同一视口 Stack 内直接比较（滚动条 10、默认 9，设为 11
  /// 可覆盖条带）；viewport 模式导航恒在整个正文视口之上，本值只与其它兄弟排序。
  /// 负值隐藏并保留布局。
  final int zIndex;

  /// 大标题是否缩小到小标题位置。
  final bool scale;

  /// 非缩放模式下是否交叉淡入淡出。
  final bool fade;

  /// 大标题在手势结束时是否吸附至展开或收起端点。
  final bool snap;

  /// 是否为折叠导航，由 collapse 构造设置，供骨架固定保留顶部安全区。
  final bool isCollapsible;

  /// 是否为渐显导航，由 fade 构造设置，供骨架将导航叠放在正文上方。
  final bool isFading;

  /// 渐显导航的标题是否同步淡入；默认常显。
  final bool fadeTitle;

  /// 顶部透明阶段的文本和图标颜色，省略时沿用最终颜色；封面页可指定白色。
  final Color? initialColor;

  /// 开始渐显时的正文滚动位置，单位为逻辑像素，与导航自然高度无关。
  final double fadeStart;

  /// 完成渐显需要的正文滚动距离，单位为逻辑像素，不改变导航布局高度。
  final double fadeDistance;

  /// 正文滚动进度映射到导航外观的曲线。
  final Curve fadeCurve;

  /// 是否跟手平移；普通跟手启用限速，位置跟手按区间映射，不能与速度阈值组合。
  final bool followDelta;

  /// 向下浏览且速度超过此值时折叠，单位为逻辑像素/秒；只填一个速度阈值时两边共用。
  final double? collapseVelocity;

  /// 向上回看且速度绝对值超过此值时展开；低速或停止保持显隐目标，回到顶部始终展开。
  final double? expandVelocity;

  /// 位置超过此值时折叠、小于等于时展开；跟手时在此值后的自然高度区间渐进收起，与速度阈值互斥。
  final double? collapseOffset;

  /// 可选搜索框，自动处理文字先淡出、背景折叠与底边线交接。
  final ElAppBarSearch? search;

  /// 是否为大标题模式，由 largeTitle 构造设置。
  final bool isLargeTitle;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).appBarBuilder!(context, this);
}

/// 搜索输入配置的公共声明。
class ElAppBarSearch extends StatelessWidget {
  /// 创建搜索框，文字、图标和光标在自然尺寸下先淡出。
  const ElAppBarSearch({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = '搜索',
    this.semanticLabel,
  });

  /// 当前查询文本。
  final String value;

  /// 用户修改查询文本时通知调用方。
  final ValueChanged<String> onChanged;

  /// 未输入时的提示。
  final String placeholder;

  /// 可访问名称，默认使用提示文字。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).appBarSearchBuilder!(context, this);
}

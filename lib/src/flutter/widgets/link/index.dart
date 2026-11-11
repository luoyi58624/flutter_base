import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/link.dart' as url_link show Link, LinkTarget;
import 'package:url_launcher/url_launcher.dart' show launchUrl;

import '../../../../dart.dart' show el;
import '../../../dart/commons/index.dart' show el;
import '../../commons/global.dart' show ElViewExt;
import '../../views/button/button_view.dart' show ElButtonView;
import '../../views/view/event/event.dart' show ElEvent, ElEventDetails, ElEventExt;
import '../../views/view/semantics/semantics.dart' show ElSemantics;
import '../../views/view/style/style.dart' show ElStyle;
import '../../views/view/view.dart' show ElView;
import '../popup/context_menu.dart' show ElContextMenuItem;
import 'status_bar.dart' show ElLinkStatusBar;

/// 链接打开目标，对齐 HTML `<a target>` 心智。
enum LinkTarget {
  /// 当前上下文打开：web 为当前标签页；非 web 平台交由系统默认方式打开。
  self,

  /// 新上下文打开：web 为新标签页；非 web 平台与 [self] 等价，统一外部打开。
  blank,
}

/// a 标签语义的超链接：外观通过 ElStyle 声明，指针 / 键盘（仅 Enter）/
/// 辅助技术三条激活路径收敛到同一份组合逻辑，激活未被拦截且有 [hrefUri] 时
/// 按 [target] 执行默认跳转，无需品牌组件或组件主题。
///
/// 与 [ElButtonView] 的三点口径差异（web `<a>` vs `<button>`）：
/// - 键盘只有 Enter 激活，没有 Space（浏览器里链接上按空格不是激活）；
/// - 不注入 `userSelect: none`，链接文字正常参与文本选区；
/// - 默认注入 `cursor: SystemMouseCursors.click`——`<a href>` 的手型光标属于
///   行为口径而非外观，调用方 [style] 声明同名字段可覆盖。
///
/// **浏览器级配套（有 [hrefUri] 时自动接线）**：
/// - 非 web：右键弹平台上下文菜单（当前仅「[copyLinkLabel]」，调用方
///   `event.onSecondaryTap` 先行且可 `preventDefault` 拦截）；悬停地址预览
///   （[ElLinkStatusBar]）由链接自身接线。
/// - web：经平台视图叠一层透明的**原生 `<a href>`**（url_launcher Link），
///   状态栏 / 右键链接菜单 / Ctrl·Cmd·中键多开全部由浏览器原生提供；框架侧
///   激活改走 followLink 协调，不再注入自有的修饰键 / 中键逻辑（避免与
///   浏览器原生行为双开）。该层对 Flutter 命中测试透明，hover / 点击回调
///   照常触发。
///
/// 组合形态而非 `extends ElView`：上述弹层与平台视图都需要 build context /
/// 包装层，widget 自身只是 [ElView] 的装配壳，样式 / 事件 / 语义仍全量透传。
///
/// 不做（首版明确不实现）：visited 态追踪、链接拖拽、`download` 属性。
class ElLink extends StatelessWidget {
  /// 构建链接。[href] 宽容输入 [Uri] / [String]（见 [parseHref]）；无 [href]
  /// 时退化为纯行为节点：激活只跑回调，不产生跳转，语义也不带 linkUrl，
  /// 右键菜单亦不接线。
  factory ElLink({
    Key? key,
    Object? href,
    LinkTarget target = .self,
    VoidCallback? onPressed,
    String? semanticLabel,
    ElStyle? style,
    ElEvent? event,
    FocusNode? focusNode,
    bool disabled = false,
    bool selected = false,
    Object? child,
  }) {
    disabled = disabled || event?.disabled == true;
    final uri = parseHref(href);
    // web 且有链接地址：走原生 <a> 平台视图，激活经 followLink 槽间接调用。
    final slot = kIsWeb && uri != null && !disabled ? _WebFollowSlot() : null;
    final void Function(LinkTarget) navigate = slot != null
        ? (t) => slot.follow?.call()
        : (t) {
            if (uri != null) openHref(uri, t);
          };
    // 可聚焦性跟随激活路径：纯展示链接（无 href / 回调 / 焦点声明）不进
    // Tab 序，对齐 <a> 无 href 不可聚焦的口径。
    final activatable = !disabled && (onPressed != null || uri != null || event?.onTap != null || focusNode != null);
    return ElLink._(
      key: key,
      hrefUri: uri,
      target: target,
      slot: slot,
      // 禁用不注入手型：引擎对 disabled 统一切 forbidden 光标。
      style: disabled ? style : const ElStyle(cursor: SystemMouseCursors.click).merge(style),
      event: _composeEvent(onPressed, uri, target, disabled, event, navigate: navigate, webNative: slot != null),
      focusNode: activatable ? focusNode : null,
      semantics: ElSemantics(
        mergeDescendants: true,
        link: true,
        linkUrl: uri,
        enabled: !disabled,
        // 口径同 ElButtonView：非选中传 null，不给普通链接白挂
        // hasSelectedState。
        selected: selected ? true : null,
        label: semanticLabel,
        onTap: _semanticsTap(onPressed, uri, target, event, disabled, navigate),
      ),
      disabled: disabled,
      selected: selected,
      child: child,
    );
  }

  /// 私有形态：全部字段已在工厂构造装配为生效值（样式注入 / 事件组合 /
  /// 焦点收敛），build 只做壳层组装。
  const ElLink._({
    super.key,
    required this.hrefUri,
    required this.target,
    required _WebFollowSlot? slot,
    required this.style,
    required this.event,
    required this.focusNode,
    required this.semantics,
    required this.disabled,
    required this.selected,
    required this.child,
  }) : _webSlot = slot;

  /// 解析后的链接地址；null 表示纯行为链接（无默认跳转、语义无 linkUrl）。
  final Uri? hrefUri;

  /// 链接打开目标（对齐 HTML `<a target>`），仅在 [hrefUri] 非 null 时有意义。
  final LinkTarget target;

  /// 生效样式：非禁用时已注入手型光标，调用方同名字段覆盖之。
  final ElStyle? style;

  /// 生效事件，包含激活逻辑与禁用配置。
  final ElEvent? event;

  /// 生效焦点节点：有激活路径时为调用方声明或 ElView 内部节点，否则 null。
  final FocusNode? focusNode;

  /// 生效语义：link 角色 + linkUrl + 与指针/键盘同路径的 tap 激活。
  final ElSemantics? semantics;

  /// 是否禁用，行为配置保存在 [event] 中。
  final bool disabled;

  /// 是否在语义树中声明选中；外观由 [style] 决定。
  final bool selected;

  /// 子内容（透传 [ElView.child] 的宽容分派：Widget / Iterable / 文本值）。
  final Object? child;

  /// web 端 followLink 槽；非 web / 无 href / 禁用为 null。
  final _WebFollowSlot? _webSlot;

  /// 非 web 右键菜单「复制链接地址」条目文案。宿主可在启动时整体替换做本地化。
  static String copyLinkLabel = '复制链接地址';

  /// 默认跳转的执行通道：激活未被 `preventDefault` 拦截时由激活逻辑调用，
  /// 默认实现是 [defaultOpenHref]。宿主可整体替换做站内路由接管（例如相对
  /// 路径走应用 router），测试注入假实现断言跳转参数。web 原生 `<a>` 路径
  /// 不经过本通道（导航由浏览器 / followLink 协调）。
  static Future<void> Function(Uri uri, LinkTarget target) openHref = defaultOpenHref;

  /// [openHref] 的默认实现：走 url_launcher，web 端按 [target] 选择当前 / 新
  /// 标签页，非 web 平台统一交由系统默认方式（外部浏览器等）打开。
  static Future<void> defaultOpenHref(Uri uri, LinkTarget target) async {
    await launchUrl(uri, webOnlyWindowName: target == LinkTarget.blank ? '_blank' : '_self');
  }

  /// 宽容解析 href 输入：[Uri] 原样、[String] 走 [Uri.tryParse]、其余值按
  /// `toString` 兜底；null 或解析失败返回 null（按无 href 处理）。
  static Uri? parseHref(Object? href) => switch (href) {
    null => null,
    Uri uri => uri,
    String s => Uri.tryParse(s),
    _ => Uri.tryParse(href.toString()),
  };

  /// 组装链接激活事件（非 web 口径）：`onTap` 组合 [onPressed] 与调用方
  /// `event.onTap`，两者都未 `preventDefault` 且有 [href] 时执行默认跳转
  /// （对齐 `<a>` 的 `event.preventDefault()` 拦截口径）。键盘只注入 Enter
  /// ——keydown 即触发、按住经 keyRepeat 回退连续触发；**不注入 Space**
  /// （web 口径：链接上空格不是激活）。调用方声明 `onKeyDown` /
  /// `onKeyRepeat` / `onKeyUp` 任意一个，内建 Enter 激活整组让位（让位理由
  /// 同 [ElButtonView.buildEvent]）。
  ///
  /// 浏览器多开口径（仅在有 [href] 时注入）：
  /// - 指针激活时按着 Ctrl / Cmd，本次跳转强制按 [LinkTarget.blank]；
  /// - 中键（tertiary）对齐 auxclick——不触发 [onPressed]，仅新上下文打开，
  ///   调用方 `event.onTertiaryTap` 先行且可 `preventDefault` 拦截。
  static ElEvent? buildEvent(VoidCallback? onPressed, Uri? href, LinkTarget target, bool disabled, ElEvent? event) {
    return _composeEvent(
      onPressed,
      href,
      target,
      disabled,
      event,
      navigate: (t) {
        if (href != null) openHref(href, t);
      },
      webNative: false,
    );
  }

  /// [buildEvent] 的通用本体。[navigate] 是跳转执行通道（非 web 为
  /// [openHref]，web 为 followLink 槽）；[webNative] 为 true 时不注入修饰键
  /// 强制新开与中键逻辑——原生 `<a>` 场景这些由浏览器处理，重复注入会双开。
  static ElEvent? _composeEvent(
    VoidCallback? onPressed,
    Uri? href,
    LinkTarget target,
    bool disabled,
    ElEvent? event, {
    required void Function(LinkTarget target) navigate,
    required bool webNative,
  }) {
    if (disabled || event?.disabled == true) return (event ?? ElEvent()).copyWith(disabled: true);
    final base = event ?? ElEvent();

    void activate(ElEventDetails e, {required bool pointer}) {
      onPressed?.call();
      base.onTap?.call(e);
      if (href == null || e.defaultPrevented) return;
      // 修饰键只对指针激活生效：键盘 Enter / 读屏没有"按住 Ctrl 点击"的语义。
      final forceBlank =
          !webNative &&
          pointer &&
          (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed);
      navigate(forceBlank ? .blank : target);
    }

    void onTap(ElEventDetails e) => activate(e, pointer: true);

    void onTertiaryTap(ElEventDetails e) {
      base.onTertiaryTap?.call(e);
      if (e.defaultPrevented) return;
      navigate(.blank);
    }

    var composed = base.copyWith(onTap: onTap);
    if (href != null && !webNative) composed = composed.copyWith(onTertiaryTap: onTertiaryTap);

    // 调用方接管任一键盘回调 → 内建 Enter 激活整组让位。
    if (base.onKeyDown != null || base.onKeyRepeat != null || base.onKeyUp != null) {
      return composed;
    }

    void onKeyDown(ElEventDetails e) {
      final key = e.logicalKey;
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        activate(e, pointer: false);
        // 显式消费：不 preventDefault 时 el 侧会忽略，Flutter 会继续处理该键。
        e.preventDefault();
      }
    }

    // 不注入 onKeyRepeat：dispatcher 对 keyRepeat 回退到 onKeyDown，按住 Enter
    // 自然连续激活；Space / Esc 完全不参与，链接没有按钮的粘滞空格语义。
    return composed.copyWith(onKeyDown: onKeyDown);
  }

  /// 辅助技术 tap 激活：与指针 / 键盘走同一份组合逻辑（[onPressed] + 调用方
  /// `event.onTap` + 默认跳转，`preventDefault` 同样可拦截）。纯 [onPressed]
  /// 且无 [href] 时直传原回调不包装，保住 [ElSemantics] `==` 的 onTap 身份
  /// 比较（口径同 [ElButtonView]）。
  static VoidCallback? _semanticsTap(
    VoidCallback? onPressed,
    Uri? href,
    LinkTarget target,
    ElEvent? event,
    bool disabled,
    void Function(LinkTarget target) navigate,
  ) {
    if (disabled || event?.disabled == true) return null;
    final eventTap = event?.onTap;
    if (eventTap == null && href == null) return onPressed;
    return () {
      onPressed?.call();
      // 辅助技术激活没有指针坐标，合成零坐标 tap 事件；也没有修饰键语义，
      // 跳转按声明的 target 执行。
      final e = ElEventDetails(phase: .tap, globalPosition: Offset.zero, localPosition: Offset.zero);
      eventTap?.call(e);
      if (href != null && !e.defaultPrevented) navigate(target);
    };
  }

  /// 非 web 的运行期事件增补（需要 build context 的部分）：右键上下文菜单。
  /// 调用方同名回调先行；构造期组合的 [event] 字段保持纯净（可被测试直接
  /// 断言）。悬停地址预览在此接线，保持各平台的链接行为一致。
  ElEvent? _runtimeEvent(BuildContext context) {
    final base = event;
    final href = hrefUri;
    if (base == null || base.disabled || href == null || kIsWeb) return base;
    final callerSecondary = base.onSecondaryTap;
    final callerEnter = base.onPointerEnter;
    final callerExit = base.onPointerExit;
    return base.copyWith(
      onPointerEnter: (e) {
        callerEnter?.call(e);
        ElLinkStatusBar.hoverEnter(context, href);
      },
      onPointerExit: (e) {
        callerExit?.call(e);
        ElLinkStatusBar.hoverExit(href);
      },
      onSecondaryTap: (e) {
        callerSecondary?.call(e);
        if (e.defaultPrevented) return;
        el.showContextMenu(
          context,
          position: e.globalPosition,
          items: [
            ElContextMenuItem(
              label: copyLinkLabel,
              onSelect: () => Clipboard.setData(ClipboardData(text: href.toString())),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = ElView(
      style: style,
      event: disabled ? ((_runtimeEvent(context)) ?? ElEvent()).copyWith(disabled: true) : (_runtimeEvent(context)),
      focusNode: focusNode,
      semantics: semantics,

      child: child,
    );
    final slot = _webSlot;
    if (slot == null) return view;
    // web：透明原生 <a> 覆盖层（Flutter 命中测试透明，child 事件照常）。
    // Link 自带的 Semantics(link, linkUrl) 与内层 ElSemantics 合并，不冲突。
    return url_link.Link(
      uri: hrefUri!,
      target: target == LinkTarget.blank ? url_link.LinkTarget.blank : url_link.LinkTarget.self,
      builder: (context, followLink) {
        slot.follow = followLink;
        return view;
      },
    );
  }
}

/// web 端 followLink 槽：[Link] builder 每次 build 刷新回调，激活路径经槽
/// 间接调用（widget 不可变，用槽对象持可变引用）。
class _WebFollowSlot {
  /// 当前 build 拿到的 followLink；平台视图尚未挂载时为 null（激活不导航）。
  Future<void> Function()? follow;
}

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, RenderEditable, RenderSemanticsAnnotations;
import 'package:flutter/widgets.dart';

import '../../../../dart.dart' show El;
import '../../components/popup/index.dart';
import '../../components/tokens.dart';
import '../../views/view/render/render_view.dart' show ElRenderView;
import '../../views/view/style/style.dart';
import 'notice.dart';

part 'modal_drag.dart';

/// 从调用位置继承主题与品牌，打开模态反馈并返回业务值。
extension ElFeedbackExt on El {
  /// 在根导航器打开底部内容弹层，支持从面板和遮罩拖动关闭并返回业务值。
  Future<T?> popup<T>(
    BuildContext context, {
    required Widget child,
    Object? title,
    Object? footer,
    bool dismissible = true,
    bool draggable = true,
    bool showClose = true,
    ElStyle? style,
  }) => _show<T>(
    context,
    ElPopup(title: title, footer: footer, showClose: showClose, style: style, child: child),
    .bottom,
    dismissible,
    draggable,
  );

  /// 打开确认对话框，footer 内通过 Navigator.pop(context, value) 返回选择结果。
  Future<T?> dialog<T>(
    BuildContext context, {
    required Widget child,
    Object? title,
    Object? footer,
    ElPopupPlacement placement = .center,
    bool dismissible = true,
    ElStyle? style,
  }) => _show<T>(
    context,
    ElDialog(title: title, footer: footer, style: style, child: child),
    placement,
    dismissible,
    false,
  );

  /// 从指定屏幕边缘打开抽屉，面板和遮罩都可沿退场方向拖动关闭。
  Future<T?> drawer<T>(
    BuildContext context, {
    required Widget child,
    Object? title,
    Object? footer,
    ElPopupPlacement placement = .right,
    bool dismissible = true,
    ElStyle? style,
  }) => _show<T>(
    context,
    ElDrawer(title: title, footer: footer, style: style, child: child),
    placement,
    dismissible,
    true,
  );

  /// 在调用窗口的根 Overlay 显示短提示，移除后完成 Future。
  Future<void> toast(
    BuildContext context,
    Object message, {
    Object? icon,
    Duration duration = const Duration(milliseconds: 2200),
    ElStyle? style,
  }) => showPopupNotice(
    context,
    duration: duration,
    child: SafeArea(
      child: Align(
        alignment: const Alignment(0, .65),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            liveRegion: true,
            child: ElToast(child: message, icon: icon, style: style),
          ),
        ),
      ),
    ),
  );
}

const _modalDuration = Duration(milliseconds: 250);
const _modalCurve = Cubic(.174, 0, .185, 1);
const _modalMargin = 16.0;

Future<T?> _show<T>(BuildContext context, ElPopup content, ElPopupPlacement placement, bool dismissible, bool drag) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final drawer = content is ElDrawer;
  final sheet = content is! ElDialog && !drawer;
  final margin = drawer ? 0.0 : _modalMargin;
  final motion = _ModalDragMotion();
  final alignment = switch (placement) {
    .center => Alignment.center,
    .bottom => Alignment.bottomCenter,
    .top => Alignment.topCenter,
    .left => Alignment.centerLeft,
    .right => Alignment.centerRight,
  };
  final horizontal = alignment.x != 0;
  final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  final label = content.semanticLabel ?? (content.title is String ? content.title as String : null);
  late final _ModalRoute<T> route;
  route = _ModalRoute<T>(
    dismissible: dismissible,
    duration: reduced ? Duration.zero : _modalDuration,
    themes: themes,
    motion: motion,
    sheet: sheet,
    pageBuilder: (context, animation, _) {
      final insets = MediaQuery.viewInsetsOf(context);
      final padding = MediaQuery.paddingOf(context);
      // 面板与遮罩共用根视口，屏幕边缘同时保留 Web 留白和系统安全区。
      final frame = EdgeInsets.fromLTRB(
        math.max(margin, padding.left),
        math.max(margin, padding.top),
        math.max(margin, padding.right),
        insets.bottom + math.max(margin, padding.bottom),
      );
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final progress = route.progress;
      final surface = label == null ? content : Semantics(namesRoute: true, label: label, child: content);
      Widget layout(Widget panel) => Padding(
        padding: frame,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final box = drawer && placement != .center
                ? BoxConstraints.tightFor(
                    width: horizontal ? math.min(360, constraints.maxWidth) : constraints.maxWidth,
                    height: horizontal ? height : math.min(420, height),
                  )
                : BoxConstraints(
                    maxWidth: sheet ? 400 : 420,
                    maxHeight: sheet ? math.min(height, viewportHeight * .85) : height,
                  );
            return Align(
              alignment: alignment,
              child: AnimatedBuilder(
                animation: progress,
                child: ConstrainedBox(constraints: box, child: panel),
                builder: (context, child) {
                  final remaining = 1 - progress.value;
                  return Opacity(
                    opacity: progress.value,
                    child: placement == .center
                        ? Transform.translate(
                            offset: Offset(0, remaining * 16),
                            child: Transform.scale(scale: 1 - remaining * .02, child: child),
                          )
                        : FractionalTranslation(
                            translation: Offset(alignment.x, alignment.y) * remaining,
                            child: Transform.translate(
                              offset: Offset(alignment.x * margin, alignment.y * margin) * remaining,
                              child: child,
                            ),
                          ),
                  );
                },
              ),
            );
          },
        ),
      );
      return themes.wrap(
        drag && placement != .center
            ? _ModalDrag(
                axis: horizontal ? .horizontal : .vertical,
                sign: alignment.x + alignment.y,
                motion: motion,
                reduced: reduced,
                animation: animation,
                layout: layout,
                child: surface,
              )
            : layout(surface),
      );
    },
  );
  return navigator.push<T>(route);
}

class _ModalRoute<T> extends RawDialogRoute<T> {
  _ModalRoute({
    required super.pageBuilder,
    required bool dismissible,
    required Duration duration,
    required this.themes,
    required this.motion,
    required this.sheet,
  }) : super(
         barrierDismissible: dismissible,
         barrierLabel: '关闭弹层',
         barrierColor: const Color(0x00000000),
         transitionDuration: duration,
         traversalEdgeBehavior: .closedLoop,
         transitionBuilder: (_, _, _, child) => child,
       );

  final CapturedThemes themes;
  final _ModalDragMotion motion;
  final bool sheet;
  late final CurvedAnimation progress;

  @override
  void install() {
    super.install();
    progress = CurvedAnimation(parent: animation!, curve: _modalCurve, reverseCurve: _modalCurve.flipped);
  }

  @override
  Widget buildModalBarrier() =>
      themes.wrap(_ModalBackdrop(progress: progress, motion: motion, sheet: sheet, child: super.buildModalBarrier()));

  @override
  bool didPop(T? result) {
    // 跟手关闭已完成退场，只需结束路由并恢复下层焦点。
    if (motion.dismissed && !willHandlePopInternally) controller!.reverseDuration = Duration.zero;
    return super.didPop(result);
  }

  @override
  void dispose() {
    progress.dispose();
    motion.dispose();
    super.dispose();
  }
}

class _ModalBackdrop extends StatelessWidget {
  const _ModalBackdrop({required this.progress, required this.motion, required this.sheet, required this.child});

  final Animation<double> progress;
  final _ModalDragMotion motion;
  final bool sheet;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = context.elVarOr(ElTokens.$overlayColor, const Color(0x570c121c));
    final blur = context.elVarOr<num>(ElTokens.$overlayBackdropBlur, 4).toDouble();
    return AnimatedBuilder(
      animation: Listenable.merge([progress, motion]),
      child: child,
      builder: (context, child) {
        // 面板位移、遮罩和模糊使用同一进度，拖动与回弹不再分段。
        final visible = progress.value * (1 - motion.distance);
        final sigma = blur * (sheet ? 1.75 : 1) * visible;
        final shade = ColoredBox(
          color: color.withValues(alpha: color.a * visible),
          child: child,
        );
        return BackdropFilter(
          enabled: sigma > 0,
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: shade,
        );
      },
    );
  }
}

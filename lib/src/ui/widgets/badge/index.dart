import 'package:flutter_base/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 独立或附着在内容右上角的徽章，背景颜色由调用方指定。
///
/// [child] 为空时徽章独立渲染；有 [child] 时钉在其右上角——位置口径同官方 CSS
/// `right: calc(1px + size/2)` + `translate(100%, -50%)`，即徽章左沿压在
/// 宿主右沿内侧 10px 处、垂直居中于宿主上沿。
class ElBadge extends StatelessWidget {
  /// 创建数字、文本或圆点徽章。
  const ElBadge({
    super.key,
    this.child,
    this.value,
    this.max = 99,
    this.isDot = false,
    this.hidden = false,
    this.showZero = true,
    required this.bgColor,
    this.offset,
    this.style,
    this.badgeStyle,
    this.semanticLabel,
  });

  /// 被标记的内容
  final Widget? child;

  /// 徽章内容，数字超过 [max] 显示 `max+`；也可直接传文本
  final Object? value;

  /// 数字超过此值时显示上限加号。
  final int max;

  /// 小圆点形态，忽略 [value]
  final bool isDot;

  /// 隐藏徽章但保留 [child]
  final bool hidden;

  /// 值为 0 时是否仍然显示
  final bool showZero;

  /// 徽章背景颜色，支持 Color 或颜色 token。
  final Color bgColor;

  /// 相对默认位置的偏移（x 正为右、y 正为下）
  final Offset? offset;

  /// 宿主容器样式。
  final ElStyle? style;

  /// 覆盖徽章默认尺寸、文字与边框的样式。
  final ElStyle? badgeStyle;

  /// 辅助技术读取的徽章说明。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = _displayValue();
    final visible = !hidden && (isDot || content != null);
    if (!visible) return child ?? const ElView();

    final mark = _mark(content);
    if (child == null) return mark;

    return ElView(
      style: style,
      child: ElStackView(
        // 徽章要溢出宿主右上角
        clipBehavior: .none,
        children: [
          child!,
          ElPositioned(
            top: (offset?.dy ?? 0),
            // 官方 dot 档收到 5px，数字档 calc(1px + 18/2) = 10px
            right: (isDot ? 5 : 10) - (offset?.dx ?? 0),
            // CSS translate(100%, -50%)：按自身尺寸的百分比平移，故用分数平移
            child: _BadgeTranslation(child: mark),
          ),
        ],
      ),
    );
  }

  Widget _mark(String? content) {
    return ElView(
      semantics: semanticLabel == null ? null : ElSemantics(container: true, label: semanticLabel),
      style:
          (isDot
                  ? ElStyle(
                      width: 8,
                      height: 8,
                      bgColor: bgColor,
                      borderRadius: BorderRadius.all(Radius.circular(9999)),
                    )
                  : ElStyle(
                      height: 18,
                      minWidth: 18,
                      padding: .symmetric(horizontal: 6),
                      alignment: .center,
                      bgColor: bgColor,
                      color: Color(0xffffffff),
                      fontSize: 12,
                      lineHeight: 1.0,
                      softWrap: false,
                      borderRadius: .all(Radius.circular(10)),
                    ))
              .merge(badgeStyle),
      child: isDot ? null : content,
    );
  }

  /// 数字超限显示 `max+`；showZero 关闭时 0 视为无内容
  String? _displayValue() {
    if (isDot) return null;
    final raw = value;
    if (raw == null) return null;
    if (raw is num) {
      if (!showZero && raw == 0) return null;
      if (raw > max) return '$max+';
    }
    return raw.toString();
  }
}

// 按徽章自身尺寸平移，避免内容位数或 badgeStyle 改变后偏移失准。
class _BadgeTranslation extends SingleChildRenderObjectWidget {
  const _BadgeTranslation({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _BadgeTranslationBox();
}

class _BadgeTranslationBox extends RenderShiftedBox {
  _BadgeTranslationBox() : super(null);

  @override
  Size computeDryLayout(BoxConstraints constraints) => child?.getDryLayout(constraints) ?? constraints.smallest;

  @override
  void performLayout() {
    final mark = child;
    if (mark == null) {
      size = constraints.smallest;
      return;
    }
    mark.layout(constraints, parentUsesSize: true);
    size = mark.size;
    (mark.parentData! as BoxParentData).offset = Offset(size.width, -size.height / 2);
  }

  @override
  Rect get paintBounds {
    final mark = child;
    if (mark == null) return super.paintBounds;
    return super.paintBounds.expandToInclude(mark.paintBounds.shift((mark.parentData! as BoxParentData).offset));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final mark = child;
    if (mark != null) context.paintChild(mark, offset + (mark.parentData! as BoxParentData).offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => hitTestChildren(result, position: position);
}

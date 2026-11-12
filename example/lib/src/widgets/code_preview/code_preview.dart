import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';

import '../panel.dart';
import 'atom_theme.dart';

/// 旧文档的恒暗代码预览，保留高亮、选择、复制与双轴滚动。
class ElCodePreview extends StatelessWidget {
  /// 创建代码预览，默认按内容完整展开高度。
  const ElCodePreview({
    super.key,
    required this.code,
    this.lang = 'dart',
    this.showLineNumbers = true,
    this.showToolbar = true,
    this.showLangLabel = true,
    this.maxHeight,
    this.borderRadius,
    this.copyButtonLabel = '复制代码',
    this.copiedLabel = '已复制',
  });

  /// 原始源码。
  final String code;

  /// 代码语言，Dart 提供语法着色，其他语言按原文展示。
  final String lang;

  /// 沿用旧实现的完整外壳模式，旧版尚未绘制行号。
  final bool showLineNumbers;

  /// 是否显示复制工具栏。
  final bool showToolbar;

  /// 是否显示语言标签。
  final bool showLangLabel;

  /// 显式限制代码区高度时启用内部纵向滚动。
  final double? maxHeight;

  /// 代码外壳圆角，嵌入示例卡时只保留底角。
  final BorderRadiusGeometry? borderRadius;

  /// 复制操作的语义标签。
  final String copyButtonLabel;

  /// 复制完成的语义标签。
  final String copiedLabel;

  @override
  Widget build(BuildContext context) => ExamplePanel(
    themeMode: ElThemeMode(brightness: .dark, duration: .zero),
    style: ElStyle(
      width: '100%',
      backgroundColor: codeBackground,
      color: codeForeground,
      iconColor: codeForeground,
      borderRadius: borderRadius ?? .circular(8),
      clipBehavior: .hardEdge,
    ),
    child: SizedBox(
      width: double.infinity,
      child: Stack(
        fit: .passthrough,
        children: [
          _CodeArea(code: code, lang: lang, maxHeight: maxHeight),
          if (showLineNumbers && showToolbar)
            Positioned(
              top: 2,
              left: 14,
              right: 8,
              child: Row(
                children: [
                  if (showLangLabel)
                    ElView(
                      style: ElStyle(fontSize: 10, lineHeight: 1, color: Color(0xff98989f)),
                      child: lang,
                    ),
                  Spacer(),
                  _CopyButton(code: code, copyLabel: copyButtonLabel, copiedLabel: copiedLabel, showLabel: true),
                ],
              ),
            ),
          if (!showLineNumbers) ...[
            if (showLangLabel && lang.isNotEmpty)
              Positioned(
                top: 15,
                right: 56,
                child: ElView(
                  style: ElStyle(color: Color(0xff98989f), fontSize: 12, fontWeight: .w500, lineHeight: 1.6),
                  child: lang,
                ),
              ),
            if (showToolbar)
              Positioned(
                top: 8,
                right: 8,
                child: _CopyButton(code: code, copyLabel: copyButtonLabel, copiedLabel: copiedLabel),
              ),
          ],
        ],
      ),
    ),
  );
}

class _CodeArea extends HookWidget {
  const _CodeArea({required this.code, required this.lang, this.maxHeight});

  final String code;
  final String lang;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final span = useMemoized(() => codeSpan(code, lang), [code, lang]);
    final scaler = MediaQuery.textScalerOf(context);
    final scaledFontSize = scaler.scale(14);
    final strut = StrutStyle(
      fontFamily: codeTextStyle.fontFamily,
      fontFamilyFallback: codeTextStyle.fontFamilyFallback,
      fontSize: 14,
      height: (scaledFontSize * 1.7).roundToDouble() / scaledFontSize,
      forceStrutHeight: true,
    );
    final direction = Directionality.of(context);
    final textHeight = useMemoized(() {
      final painter = TextPainter(
        text: TextSpan(style: codeTextStyle, children: [span]),
        textScaler: scaler,
        textDirection: direction,
        strutStyle: strut,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }, [span, scaler, direction, strut]);
    final text = Text.rich(span, style: codeTextStyle, softWrap: false, strutStyle: strut);
    // 横向 ElScrollView 需要有限的交叉轴高度，按原有源码行高测量。
    final content = LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: textHeight + 40,
        child: ElScrollView(
          scrollDirection: .horizontal,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Padding(padding: .symmetric(vertical: 20, horizontal: 24), child: text),
            ),
          ],
        ),
      ),
    );
    // 默认纵向完全展开，只有显式限高时才创建内部纵向视口。
    final area = maxHeight == null || textHeight + 40 <= maxHeight!
        ? content
        : SizedBox(
            height: maxHeight,
            child: ElScrollView(children: [content]),
          );
    return SelectionArea(child: area);
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.code, required this.copyLabel, required this.copiedLabel, this.showLabel = false});

  final String code;
  final String copyLabel;
  final String copiedLabel;
  final bool showLabel;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    super.dispose();
  }

  @override
  void didUpdateWidget(_CopyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _generation++;
      _copied = false;
    }
  }

  void _onPointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    _generation++;
    if (_copied && mounted) setState(() => _copied = false);
  }

  Future<void> _copy() async {
    final generation = _generation;
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted && generation == _generation) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) => ElButtonView(
    onPressed: _copy,
    selected: _copied,
    semanticLabel: _copied ? widget.copiedLabel : widget.copyLabel,
    style: widget.showLabel
        ? ElStyle(
            height: 20,
            padding: .symmetric(horizontal: 4),
            alignment: .center,
            borderRadius: .circular(4),
            cursor: SystemMouseCursors.click,
            onHover: ElStyle(backgroundColor: Color(0x18ffffff)),
            onFocusVisible: ElStyle(
              outline: ElOutline(outlineWidth: 1, outlineColor: codeForeground, outlineOffset: 1),
            ),
          )
        : ElStyle(
            width: 36,
            height: 36,
            alignment: .center,
            backgroundColor: Color(0xff202127),
            border: .all(borderColor: Color(0xff2e2e32)),
            borderRadius: .circular(18),
            cursor: SystemMouseCursors.click,
            onHover: ElStyle(backgroundColor: Color(0xff2e3440)),
            onFocusVisible: ElStyle(
              outline: ElOutline(outlineWidth: 2, outlineColor: Color(0xff61afef), outlineOffset: 1),
            ),
          ),
    child: Row(
      mainAxisSize: .min,
      spacing: 5,
      children: [
        ElView(
          style: ElStyle(iconColor: codeForeground, iconSize: widget.showLabel ? 12 : 16, lineHeight: 1),
          child: _copied ? Icons.check : Icons.copy_all_outlined,
        ),
        if (widget.showLabel)
          ElView(
            style: ElStyle(color: Color(0xff98989f), fontSize: 10, lineHeight: 1),
            child: _copied ? widget.copiedLabel : widget.copyLabel,
          ),
      ],
    ),
  );
}

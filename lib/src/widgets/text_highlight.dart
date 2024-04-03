part of flutter_base;

/// 文字高亮组件
class TextHighlightWidget extends StatelessWidget {
  const TextHighlightWidget({
    super.key,
    required this.text,
    required this.highlightText,
    this.color,
    this.textStyle,
    this.overflow = TextOverflow.visible,
  });

  /// 源文字
  final String text;

  /// 高亮文字
  final String highlightText;

  /// 高亮颜色，默认红色
  final Color? color;

  final TextStyle? textStyle;

  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    return TextHighlight(
      text: text,
      words: highlightText == ''
          ? const {}
          : {
              highlightText: HighlightedWord(
                textStyle: TextStyle(
                  color: color ?? Colors.red,
                ),
              )
            },
      overflow: overflow,
      textStyle: textStyle,
    );
  }
}

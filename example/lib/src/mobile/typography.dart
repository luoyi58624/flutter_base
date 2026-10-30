part of 'app.dart';

class _Typography {
  const _Typography();
  ElStyle style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _secondary,
  }) => ElStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    lineHeight: 1.3,
  );
}

class _Label extends StatelessWidget {
  const _Label(
    this.text,
    this.typography, {
    super.key,
    this.size = 13,
    this.weight = FontWeight.w400,
    this.color = _secondary,
    this.maxLines,
    this.extraLeading = 0,
    this.letterSpacing,
    this.align,
  });
  final String text;
  final _Typography typography;
  final double size, extraLeading;
  final FontWeight weight;
  final Color color;
  final int? maxLines;
  final double? letterSpacing;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) => ElText(
    text,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.3 + extraLeading / size,
      letterSpacing: letterSpacing,
    ),
    maxLines: maxLines,
    overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
    textAlign: align,
  );
}
